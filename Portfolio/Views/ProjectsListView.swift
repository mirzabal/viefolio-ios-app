import SwiftUI
import FirebaseAuth

// MARK: - Projects List

struct ProjectsListView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var firestoreService = FirestoreService.shared
    @State private var showCreateSheet = false
    @State private var projectToDelete: Project?

    var body: some View {
        NavigationStack {
            Group {
                if firestoreService.isLoading && firestoreService.projects.isEmpty {
                    ProgressView("Loading projects…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if firestoreService.errorMessage != nil && firestoreService.projects.isEmpty {
                    syncErrorState
                } else if firestoreService.projects.isEmpty {
                    emptyState
                } else {
                    projectsList
                }
            }
            .background(Color.canvas)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !firestoreService.projects.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                ProjectFormView(mode: .create)
            }
            .confirmationDialog(
                "Delete \"\(projectToDelete?.title ?? "")\"?",
                isPresented: Binding(
                    get: { projectToDelete != nil },
                    set: { if !$0 { projectToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Project", role: .destructive) {
                    if let project = projectToDelete {
                        Task { await firestoreService.deleteProject(projectId: project.id) }
                    }
                    projectToDelete = nil
                }
            } message: {
                Text("This removes the project from your portfolio permanently.")
            }
        }
    }

    private var projectsList: some View {
        List {
            ForEach(firestoreService.projects) { project in
                NavigationLink(value: project.id) {
                    ProjectRowView(project: project)
                }
                .listRowBackground(Color.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        projectToDelete = project
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        Task { await firestoreService.setProjectVisible(project, visible: !project.visible) }
                    } label: {
                        Label(project.visible ? "Hide" : "Show",
                              systemImage: project.visible ? "eye.slash" : "eye")
                    }
                    .tint(.brandFill)
                }
            }
            .onMove { source, destination in
                var reordered = firestoreService.projects
                reordered.move(fromOffsets: source, toOffset: destination)
                firestoreService.projects = reordered
                Task { await firestoreService.saveProjectOrder(reordered) }
            }
        }
        .viefolioBackground()
        .refreshable { await firestoreService.refresh() }
        .navigationDestination(for: String.self) { projectId in
            ProjectDetailView(projectId: projectId)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects Yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Create your first project and it will appear on your Viefolio portfolio instantly.")
        } actions: {
            Button("Create Project") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandFill)
        }
    }

    // Sync hatası "hiç projen yok" gibi görünmesin — açıkça söyle ve retry ver
    private var syncErrorState: some View {
        ContentUnavailableView {
            Label("Can't Reach Your Portfolio", systemImage: "wifi.exclamationmark")
        } description: {
            Text(firestoreService.errorMessage ?? "Something went wrong while syncing.")
        } actions: {
            Button("Try Again") {
                if let uid = authService.currentUser?.uid {
                    firestoreService.startListening(userUid: uid)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandFill)
        }
    }
}

#Preview {
    ProjectsListView()
        .environment(AuthenticationService())
}
