import SwiftUI
import FirebaseAuth

// MARK: - ContentView (Root TabView — Auth'lu kullanıcılar için)

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        tabs
    }

    private var tabs: some View {
        TabView {
            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.brand)
        .task(id: authService.currentUser?.uid) {
            if let uid = authService.currentUser?.uid {
                FirestoreService.shared.startListening(userUid: uid)
                await SessionService.shared.recordSession(uid: uid)
            } else {
                FirestoreService.shared.stopListening()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let uid = authService.currentUser?.uid else { return }
            FirestoreService.shared.startListening(userUid: uid)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthenticationService())
}
