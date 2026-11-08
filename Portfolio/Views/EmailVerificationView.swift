import SwiftUI

// MARK: - Email verification (6-digit code)
// Mirrors the web sign-up step: the code is issued by /api/password-otp/request
// and confirmed by /api/verify-email.

struct EmailVerificationView: View {
    @Environment(AuthenticationService.self) private var authService

    let email: String

    @State private var code = ""
    @State private var busy = false
    @State private var message: String?
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brand)
                    Text("Check your email")
                        .font(.title3.weight(.bold))
                    Text("Enter the 6-digit code we sent to \(email) to unlock your account. It expires in 10 minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .tracking(8)
                    .focused($codeFocused)
                    .padding(.vertical, 14)
                    .background(Color.subtle, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: code) { _, new in
                        code = String(new.filter(\.isNumber).prefix(6))
                    }

                if let errorMessage {
                    label(errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
                } else if let message {
                    label(message, color: .brandSoft, icon: "checkmark.circle.fill")
                }

                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if busy { ProgressView().tint(.white) } else { Text("Verify email") }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandFill)
                .disabled(busy || code.count != 6)

                Button("Didn't get it? Resend") {
                    Task { await resend() }
                }
                .font(.subheadline)
                .tint(.brand)
                .disabled(busy)

                Spacer()
            }
            .padding(24)
            .background(Color.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { authService.signOut() }
                        .tint(.brand)
                }
            }
            .onAppear { codeFocused = true }
            // Sign-up already mailed a code; arriving here from a sign-in hasn't.
            .task {
                guard !authService.verificationCodeSent else { return }
                do { try await authService.sendEmailVerificationCode() }
                catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private func label(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
            Text(text).font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
    }

    private func verify() async {
        busy = true
        errorMessage = nil
        message = nil
        do {
            try await authService.confirmEmailVerificationCode(code)
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }

    private func resend() async {
        busy = true
        errorMessage = nil
        message = nil
        do {
            try await authService.sendEmailVerificationCode()
            message = "New code sent."
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}
