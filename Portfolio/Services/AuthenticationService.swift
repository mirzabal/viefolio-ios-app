import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Observation

// MARK: - Authentication Service

@Observable
final class AuthenticationService {
    
    // MARK: - Published Properties
    
    var currentUser: FirebaseAuth.User?
    var isAuthenticated: Bool { 
        currentUser != nil 
    }
    var isLoading = false
    var errorMessage: String?
    /// True only for password accounts whose address isn't confirmed yet.
    var needsEmailVerification = false
    /// Guards against mailing a second code to someone who just got one.
    var verificationCodeSent = false
    
    // MARK: - Private
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    // MARK: - Initialization
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            // Password sign-ups only — Google and Apple arrive already verified.
            self?.needsEmailVerification = user.map {
                !$0.isEmailVerified && $0.providerData.contains { $0.providerID == "password" }
            } ?? false
        }
    }

    // MARK: - Email Verification (6-digit code)

    /// Re-checks the server's verification state. The code endpoint flips the
    /// auth record, so a reload is all it takes to notice.
    func refreshEmailVerification() async {
        guard let user = Auth.auth().currentUser,
              user.providerData.contains(where: { $0.providerID == "password" })
        else { needsEmailVerification = false; return }

        try? await user.reload()
        needsEmailVerification = !user.isEmailVerified
    }

    /// Sends a 6-digit code — the same OTP endpoint the web uses.
    func sendEmailVerificationCode() async throws {
        _ = try await callAPI("password-otp/request", body: ["purpose": "EMAIL_VERIFY"])
        verificationCodeSent = true
    }

    /// Confirms the code. On success the token is refreshed so Firestore rules
    /// see `email_verified` on the very next write.
    func confirmEmailVerificationCode(_ code: String) async throws {
        _ = try await callAPI("verify-email", body: ["code": code])
        if let user = Auth.auth().currentUser {
            _ = try? await user.getIDTokenResult(forcingRefresh: true)
            try? await user.reload()
        }
        needsEmailVerification = false
        verificationCodeSent = false
    }

    struct APIError: LocalizedError {
        let errorDescription: String?
    }

    @discardableResult
    private func callAPI(_ path: String, body: [String: String]) async throws -> Data {
        guard let user = Auth.auth().currentUser else {
            throw APIError(errorDescription: "You're signed out. Sign in and try again.")
        }
        let idToken = try await user.getIDToken()
        var request = URLRequest(url: URL(string: "https://viefolio.com/api/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError(errorDescription: message ?? "Something went wrong. Please try again.")
        }
        return data
    }

    // MARK: - Error Mapping

    private func friendlyMessage(for error: Error) -> String? {
        let nsError = error as NSError
        print("🔐 Auth error [\(nsError.domain) \(nsError.code)]: \(error.localizedDescription)")

        if let asError = error as? ASAuthorizationError, asError.code == .canceled { return nil }
        if nsError.domain == kGIDSignInErrorDomain, nsError.code == GIDSignInError.canceled.rawValue { return nil }

        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return "Something went wrong. Please try again."
        }
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .userDisabled:
            return "This account has been disabled."
        case .operationNotAllowed:
            return "This sign-in method isn't enabled yet."
        case .accountExistsWithDifferentCredential:
            return "This email is registered with a different sign-in method."
        default:
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Email / Password Authentication
    
    func registerWithEmail(email: String, password: String, fullName: String, username: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            try await changeRequest.commitChanges()

            do {
                try await FirestoreService.shared.claimUsernameAndCreateProfile(
                    username: username,
                    fullName: fullName,
                    uid: result.user.uid,
                    emailVerified: false
                )
            } catch {
                await FirestoreService.shared.ensureProfile(uid: result.user.uid, displayName: fullName, emailVerified: false)
                errorMessage = "Your account was created, but that username was just taken. You can pick a new one on viefolio.com."
            }

            currentUser = result.user

            // Google and Apple hand us an address their provider already
            // verified; only password sign-ups get a code.
            needsEmailVerification = true
            try? await sendEmailVerificationCode()
        } catch {
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await FirestoreService.shared.ensureProfile(uid: result.user.uid, displayName: result.user.displayName)

            currentUser = result.user
        } catch {
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }

    // MARK: - Google Sign In

    @MainActor
    func signInWithGoogle() async throws {
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In isn't configured yet."
            throw AuthError.invalidCredential
        }
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            errorMessage = "Something went wrong. Please try again."
            throw AuthError.invalidCredential
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredential
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            await FirestoreService.shared.ensureProfile(
                uid: authResult.user.uid,
                displayName: authResult.user.displayName
            )

            currentUser = authResult.user
        } catch {
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Apple Sign In

    // Called from SignInWithAppleButton's request closure — the button presents the sheet itself.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    // Called from the button's onCompletion with the credential it already obtained — no second sheet.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let authorization: ASAuthorization
            switch result {
            case .success(let auth): authorization = auth
            case .failure(let error): throw error
            }

            guard let nonce = currentNonce,
                  let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.invalidCredential
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            let authResult = try await Auth.auth().signIn(with: credential)

            let displayName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")
            await FirestoreService.shared.ensureProfile(
                uid: authResult.user.uid,
                displayName: displayName.isEmpty ? authResult.user.displayName : displayName
            )

            currentUser = authResult.user
        } catch {
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }

    // MARK: - Change Password

    var isPasswordUser: Bool {
        currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    @MainActor
    func changePassword(currentPassword: String, newPassword: String, signOutOtherDevices: Bool) async throws {
        guard let user = currentUser, let email = user.email else {
            errorMessage = "Something went wrong. Please try again."
            throw AuthError.userNotFound
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)

            if signOutOtherDevices {
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
                let keepSessionId = "ios-\(deviceId)"

                do {
                    let idToken = try await user.getIDToken()
                    var request = URLRequest(url: URL(string: "https://viefolio.com/api/revoke-sessions")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(["keepSessionId": keepSessionId])
                    request.timeoutInterval = 10
                    _ = try await URLSession.shared.data(for: request)
                } catch {
                    await FirestoreService.shared.deleteOtherSessions(userUid: user.uid, keepSessionId: keepSessionId)
                }

                // revoke kills this device's token too — sign in again so we stay logged in
                let result = try await Auth.auth().signIn(withEmail: email, password: newPassword)
                currentUser = result.user
            }

            // Restart the streams with a fresh token — a stale listener can look like an empty account
            FirestoreService.shared.startListening(userUid: user.uid)
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               let code = AuthErrorCode(rawValue: nsError.code),
               code == .wrongPassword || code == .invalidCredential {
                errorMessage = "Current password is incorrect."
            } else {
                errorMessage = friendlyMessage(for: error)
            }
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            currentUser = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }
    
    // MARK: - Apple Sign In Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Apple Sign In credential is invalid."
        case .userNotFound:
            return "User not found."
        }
    }
}
