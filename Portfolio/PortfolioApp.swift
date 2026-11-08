import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct PortfolioApp: App {
    
    init() {
        FirebaseApp.configure()

        // One nav bar look for every tab: canvas shows through, cream titles in dark.
        // (An opaque appearance hides large titles on iOS 26.)
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        let title = UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: 0xFDFBF3)) : .label }
        bar.titleTextAttributes = [.foregroundColor: title]
        bar.largeTitleTextAttributes = [.foregroundColor: title]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
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
