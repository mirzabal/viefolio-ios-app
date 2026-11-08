import SwiftUI
import FirebaseAuth

// MARK: - Settings Tab

struct SettingsView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var firestoreService = FirestoreService.shared
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false

    private var username: String {
        firestoreService.profile?.username ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Account
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.currentUser?.displayName
                                 ?? firestoreService.profile?.fullName
                                 ?? "Viefolio User")
                                .font(.headline)
                            Text(authService.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Account")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)

                // MARK: Portfolio
                Section {
                    if !username.isEmpty, let url = URL(string: "https://\(username).viefolio.com") {
                        Link(destination: url) {
                            HStack {
                                Label("View My Portfolio", systemImage: "safari.fill")
                                Spacer()
                                Text("\(username).viefolio.com")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                        ShareLink(item: url) {
                            Label("Share Portfolio Link", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label {
                            Text("Set a username on viefolio.com to get your public portfolio link.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.brand)
                        }
                    }
                } header: {
                    Text("Portfolio")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)

                // MARK: Security
                if authService.isPasswordUser {
                    Section {
                        Button {
                            showChangePassword = true
                        } label: {
                            Label("Change Password", systemImage: "key.fill")
                                .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Security")
                            .foregroundStyle(Color.headerInk)
                    }
                    .listRowBackground(Color.surface)
                }

                // MARK: Developer
                Section {
                    NavigationLink {
                        APISettingsView()
                    } label: {
                        Label("API Access", systemImage: "server.rack")
                    }
                } header: {
                    Text("Developer")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)

                // MARK: Session
                Section {
                    Button(role: .destructive) {
                        FirestoreService.shared.stopListening()
                        authService.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(Color.surface)
                
                // MARK: Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAccount = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Permanently deletes your portfolio, projects, images and login. Requires a code sent to your email.")
                }
                .listRowBackground(Color.surface)
            }
            .viefolioBackground()
            .navigationTitle("Settings")
            .refreshable { await firestoreService.refresh() }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationService.self) private var authService

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var signOutOtherDevices = true
    @State private var isWorking = false
    @State private var message: String?
    @State private var isError = false

    private var canRequest: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New password (min 6 characters)", text: $newPassword)
                        .textContentType(.newPassword)
                        .disabled(codeSent)
                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .disabled(codeSent)
                } footer: {
                    if !confirmPassword.isEmpty && confirmPassword != newPassword {
                        Text("Passwords don't match.").foregroundStyle(.red)
                    }
                }
                .listRowBackground(Color.surface)

                Section {
                    Toggle("Sign out of all other devices", isOn: $signOutOtherDevices)
                        .toggleStyle(.viefolio)
                }
                .listRowBackground(Color.surface)

                if codeSent {
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .font(.title3.weight(.semibold))
                            .onChange(of: code) { _, v in
                                code = String(v.filter(\.isNumber).prefix(6))
                            }
                        Button("Didn't get it? Edit & resend") {
                            codeSent = false
                            code = ""
                            message = nil
                        }
                        .font(.caption)
                    } header: {
                        Text("Verification code")
                            .foregroundStyle(Color.headerInk)
                    }
                    .listRowBackground(Color.surface)
                }

                if let message {
                    Section {
                        Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isError ? .red : .green)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .viefolioBackground()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else if codeSent {
                        Button("Confirm") { Task { await confirm() } }
                            .disabled(code.count != 6)
                    } else {
                        Button("Send Code") { Task { await requestCode() } }
                            .disabled(!canRequest)
                    }
                }
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    private func requestCode() async {
        guard let user = authService.currentUser else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token = try await user.getIDToken()
            var req = URLRequest(url: URL(string: "https://viefolio.com/api/password-otp/request")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200 {
                codeSent = true
                isError = false
                message = "Code sent to \(user.email ?? "your email"). It expires in 10 minutes."
            } else {
                isError = true
                message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                    ?? "Couldn't send the code. Try again."
            }
        } catch {
            isError = true
            message = "Couldn't send the code. Check your connection."
        }
    }

    private func confirm() async {
        guard let user = authService.currentUser, let email = user.email else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token = try await user.getIDToken()
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
            var req = URLRequest(url: URL(string: "https://viefolio.com/api/password-otp/confirm")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "code": code,
                "newPassword": newPassword,
                "signOutOtherDevices": signOutOtherDevices,
                "keepSessionId": "ios-\(deviceId)",
            ])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                isError = true
                message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                    ?? "Couldn't change the password."
                return
            }
            // Server-side change revokes this device's tokens too — sign in fresh
            let result = try await Auth.auth().signIn(withEmail: email, password: newPassword)
            authService.currentUser = result.user
            FirestoreService.shared.startListening(userUid: result.user.uid)
            isError = false
            message = "Password changed successfully."
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        } catch {
            isError = true
            message = "Password may have changed, but signing back in failed — sign in with the new password."
        }
    }
}

//MARK: DeleteAccountView

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationService.self) private var authService

    @State private var confirmText = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isWorking = false
    @State private var message: String?

    private var username: String {
        FirestoreService.shared.profile?.username ?? ""
    }
    private var confirmPhrase: String {
        username.isEmpty ? "DELETE" : username
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your portfolio\(username.isEmpty ? "" : " at \(username).viefolio.com"), all your projects, images, and your login. This cannot be undone.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Color.surface)

                Section {
                    TextField(confirmPhrase, text: $confirmText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Type \"\(confirmPhrase)\" to continue")
                        .foregroundStyle(Color.headerInk)
                }
                .listRowBackground(Color.surface)

                if codeSent {
                    Section {
                        TextField("6-digit code from your email", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .font(.title3.weight(.semibold))
                            .onChange(of: code) { _, v in
                                code = String(v.filter(\.isNumber).prefix(6))
                            }
                    } header: {
                        Text("Verification code")
                            .foregroundStyle(Color.headerInk)
                    }
                    .listRowBackground(Color.surface)
                }

                if let message {
                    Section {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
                    .listRowBackground(Color.surface)
                }

                Section {
                    if !codeSent {
                        Button("Email Me a Deletion Code", role: .destructive) {
                            Task { await requestCode() }
                        }
                        .disabled(confirmText != confirmPhrase || isWorking)
                    } else {
                        Button(isWorking ? "Deleting…" : "Delete Forever", role: .destructive) {
                            Task { await deleteAccount() }
                        }
                        .disabled(code.count != 6 || isWorking)
                    }
                }
                .listRowBackground(Color.surface)
            }
            .viefolioBackground()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isWorking)
                }
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    private func requestCode() async {
        guard let user = authService.currentUser else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token = try await user.getIDToken()
            var req = URLRequest(url: URL(string: "https://viefolio.com/api/password-otp/request")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["purpose": "DELETE_ACCOUNT"])
            let (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200 {
                codeSent = true
                message = nil
            } else {
                message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                    ?? "Couldn't send the code. Try again."
            }
        } catch {
            message = "Couldn't send the code. Check your connection."
        }
    }

    private func deleteAccount() async {
        guard let user = authService.currentUser else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token = try await user.getIDToken()
            var req = URLRequest(url: URL(string: "https://viefolio.com/api/delete-account")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                    ?? "Couldn't delete the account. Try again."
                return
            }
            // Server already removed the auth user + data; clear local state
            FirestoreService.shared.stopListening()
            authService.signOut()
            dismiss()
        } catch {
            message = "Something went wrong. Check your connection and try again."
        }
    }
}
