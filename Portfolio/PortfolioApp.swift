import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct PortfolioApp: App {
    
    init() {
        FirebaseApp.configure()
        print("🔥 Firebase EN BAŞTA, her şeyden önce başlatıldı!")
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
                ContentView()
            } else {
                AuthenticationView()
            }
        }
        .environment(authService) 
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}
