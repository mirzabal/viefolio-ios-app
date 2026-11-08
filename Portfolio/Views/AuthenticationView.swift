import SwiftUI
import AuthenticationServices

// MARK: - Authentication View

struct AuthenticationView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var username = ""

    enum UsernameStatus { case idle, checking, available, taken, invalid }
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>?

    private let brandGradient = LinearGradient(
        colors: [Color.brand, Color.brandSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                card
                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(duration: 0.35), value: isRegistering)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack() {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                Text("VieFolio")
                    .font(.title.weight(.semibold))
                    .tracking(-0.5)
            }
            .padding(.top, 24)

            VStack(spacing: 4) {
                Text(isRegistering ? "Create your account" : "Welcome back")
                    .font(.title3.weight(.bold))
                Text(isRegistering ? "Start building your living portfolio" : "Sign in to continue to your portfolio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .id(isRegistering) // mode değişince yumuşak geçiş
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 18) {
            SignInWithAppleButton(isRegistering ? .signUp : .signIn) { request in
                authService.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { try? await authService.completeAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { try? await authService.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image("GoogleLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Continue with Google")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, lineWidth: 0.5))
                .foregroundStyle(.primary)
            }
            .disabled(authService.isLoading)

            HStack(spacing: 12) {
                Rectangle().fill(Color.hairline).frame(height: 0.5)
                Text("or continue with email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle().fill(Color.hairline).frame(height: 0.5)
            }

            VStack(spacing: 14) {
                if isRegistering {
                    field("Full Name") {
                        TextField("John Smith", text: $fullName)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }
                    usernameField
                }

                field("Email") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                field("Password") {
                    SecureField("At least 6 characters", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                }

                if isRegistering {
                    field("Confirm Password") {
                        SecureField("Repeat your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    if !confirmPassword.isEmpty && confirmPassword != password {
                        inlineNote("Passwords don't match.", color: .red, icon: "exclamationmark.circle.fill")
                    }
                }
            }

            if let error = authService.errorMessage {
                inlineNote(error, color: .red, icon: "exclamationmark.triangle.fill")
            }

            submitButton

            Button {
                isRegistering.toggle()
                authService.errorMessage = nil
            } label: {
                Group {
                    if isRegistering {
                        Text("Already have an account? ").foregroundStyle(.secondary)
                        + Text("Sign in").bold().foregroundStyle(.brand)
                    } else {
                        Text("Don't have an account? ").foregroundStyle(.secondary)
                        + Text("Create one").bold().foregroundStyle(.brand)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(24)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }

    // MARK: Username field with live availability

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Username")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, newValue in
                        let sanitized = sanitizeUsername(newValue)
                        if sanitized != newValue { username = sanitized }
                        scheduleUsernameCheck(sanitized)
                    }
                usernameStatusIcon
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.canvas, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(username.isEmpty ? "yourname.viefolio.com" : "\(username).viefolio.com")
            }
            .font(.caption2)
            .foregroundStyle(usernameStatus == .taken ? .red : .secondary)

            if usernameStatus == .taken {
                inlineNote("\"\(username)\" is already taken — try \(username)-dev or \(username)hq.", color: .red, icon: "xmark.circle.fill")
            }
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        switch usernameStatus {
        case .idle, .invalid:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .taken:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: Submit

    private var canSubmit: Bool {
        guard !email.isEmpty, password.count >= 6, !authService.isLoading else { return false }
        if isRegistering {
            return !fullName.trimmingCharacters(in: .whitespaces).isEmpty
                && username.count >= 2
                && usernameStatus != .taken
                && usernameStatus != .checking
                && confirmPassword == password
        }
        return true
    }

    private var submitButton: some View {
        Button {
            Task {
                if isRegistering {
                    try? await authService.registerWithEmail(
                        email: email,
                        password: password,
                        fullName: fullName.trimmingCharacters(in: .whitespaces),
                        username: username
                    )
                } else {
                    try? await authService.signInWithEmail(email: email, password: password)
                }
            }
        } label: {
            HStack(spacing: 10) {
                if authService.isLoading {
                    ProgressView().tint(Color.onBrand)
                }
                Text(isRegistering ? "Create Account" : "Sign In")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(brandGradient, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Color.onBrand)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .disabled(!canSubmit)
    }

    // MARK: Footer

    private var footer: some View {
        Text("By continuing, you agree to VieFolio's [Terms of Service](https://viefolio.com/terms) and [Privacy Policy](https://viefolio.com/privacy).")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .tint(.brand)
            .multilineTextAlignment(.center)
    }

    // MARK: Helpers

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.canvas, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func inlineNote(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func sanitizeUsername(_ raw: String) -> String {
        String(raw.lowercased().filter { $0.isLowercase || $0.isNumber || $0 == "-" }.prefix(30))
    }

    private func scheduleUsernameCheck(_ value: String) {
        usernameCheckTask?.cancel()
        guard value.count >= 2 else {
            usernameStatus = value.isEmpty ? .idle : .invalid
            return
        }
        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500)) // debounce
            guard !Task.isCancelled else { return }
            let available = await FirestoreService.shared.isUsernameAvailable(value)
            guard !Task.isCancelled else { return }
            switch available {
            case .some(true):  usernameStatus = .available
            case .some(false): usernameStatus = .taken
            case .none:        usernameStatus = .idle // okuma izni yoksa kayıt anında transaction yakalar
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environment(AuthenticationService())
}
