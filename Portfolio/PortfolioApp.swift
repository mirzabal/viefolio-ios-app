import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct PortfolioApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @State private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.needsEmailVerification {
                    // Nothing in the app is reachable until the code is entered.
                    EmailVerificationView(email: authService.currentUser?.email ?? "your email")
                } else {
                    ContentView()
                }
            } else {
                AuthenticationView()
            }
        }
        .environment(authService)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.needsEmailVerification)
        .task { await authService.refreshEmailVerification() }
    }
}
