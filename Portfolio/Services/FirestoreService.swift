import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firestore Service

@Observable
final class FirestoreService {
    // MARK: - Singleton

    static let shared = FirestoreService()

    // MARK: - State

    var projects: [Project] = []
    var profile: Profile?
    var visitStats = VisitStats()
    var sessions: [DeviceSession] = []
    var statsLoaded = false
    var sessionsLoaded = false
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var projectsListener: ListenerRegistration?
    private var profileListener: ListenerRegistration?
    private var statsListener: ListenerRegistration?
    private var sessionsListener: ListenerRegistration?

    private init() {}

    // MARK: - Realtime Listeners

    @MainActor
    func startListening(userUid: String) {
        stopListening()
        isLoading = true

        projectsListener = db.collection("projects")
            .whereField("userId", isEqualTo: userUid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Firestore listener error: \(error)")
                    self.errorMessage = "Couldn't sync with the server. Check your connection and try again."
                    return
                }
                let docs = snapshot?.documents.map { Project(id: $0.documentID, data: $0.data()) } ?? []
                self.projects = docs.sorted { $0.orderIndex < $1.orderIndex }
            }

        profileListener = db.collection("profiles").document(userUid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Firestore listener error: \(error)")
                    self.errorMessage = "Couldn't sync with the server. Check your connection and try again."
                    return
                }
                if let snapshot, snapshot.exists {
                    self.profile = Profile(userId: userUid, data: snapshot.data() ?? [:])
                } else {
                    self.profile = Profile(fullName: "", userId: userUid)
                }
            }

        statsListener = db.collection("stats").document(userUid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                var daily: [String: Int] = [:]
                for (key, value) in (data["daily"] as? [String: Any] ?? [:]) {
                    daily[key] = value as? Int ?? 0
                }
                self.visitStats = VisitStats(
                    totalVisits: data["totalVisits"] as? Int ?? 0,
                    daily: daily,
                    lastVisitAt: (data["lastVisitAt"] as? Timestamp)?.dateValue()
                )
                self.statsLoaded = true
                WidgetDataStore.save(stats: self.visitStats, username: self.profile?.username ?? "")
            }

        sessionsListener = db.collection("profiles").document(userUid).collection("sessions")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents.map { doc -> DeviceSession in
                    let d = doc.data()
                    return DeviceSession(
                        id: doc.documentID,
                        platform: d["platform"] as? String ?? "WEB",
                        deviceModel: d["deviceModel"] as? String ?? "Unknown device",
                        osVersion: d["osVersion"] as? String ?? "",
                        location: d["location"] as? String ?? "",
                        lastSignIn: (d["lastSignIn"] as? Timestamp)?.dateValue()
                    )
                } ?? []
                self.sessions = docs.sorted { ($0.lastSignIn ?? .distantPast) > ($1.lastSignIn ?? .distantPast) }
                self.sessionsLoaded = true
            }
    }

    /// Pull-to-refresh: re-attach listeners so a fresh server snapshot comes in.
    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        startListening(userUid: uid)
        // ponytail: listeners have no completion handler; short wait so the spinner isn't a flash
        try? await Task.sleep(for: .milliseconds(600))
    }

    func stopListening() {
        projectsListener?.remove()
        profileListener?.remove()
        statsListener?.remove()
        sessionsListener?.remove()
        projectsListener = nil
        profileListener = nil
        statsListener = nil
        sessionsListener = nil
        projects = []
        profile = nil
        visitStats = VisitStats()
        sessions = []
        statsLoaded = false
        sessionsLoaded = false
    }

    @MainActor
    func deleteOtherSessions(userUid: String, keepSessionId: String) async {
        let batch = db.batch()
        for session in sessions where session.id != keepSessionId {
            batch.deleteDocument(
                db.collection("profiles").document(userUid).collection("sessions").document(session.id)
            )
        }
        do {
            try await batch.commit()
        } catch {
            print("❌ DeleteOtherSessions error: \(error)")
        }
    }

    // MARK: - Project CRUD

    @MainActor
    func createProject(_ project: Project, userUid: String) async -> String? {
        var data = project.firestoreData
        data["userId"] = userUid
        data["orderIndex"] = (projects.map(\.orderIndex).max() ?? -1) + 1
        data["visible"] = true
        do {
            let ref = try await db.collection("projects").addDocument(data: data)
            return ref.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func setProjectImageUrl(_ url: String, projectId: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData(["imageUrl": url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // updateData, not setData: a full overwrite would wipe fields only the web writes
    @MainActor
    func updateProject(_ project: Project) async -> Bool {
        do {
            try await db.collection("projects").document(project.id)
                .updateData(project.firestoreData)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func setProjectVisible(_ project: Project, visible: Bool) async {
        do {
            try await db.collection("projects").document(project.id)
                .updateData(["visible": visible])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleCheckpoint(project: Project, checkpointId: String) async {
        let updated = project.checkpoints.map { cp in
            var cp = cp
            if cp.id == checkpointId { cp.isCompleted.toggle() }
            return cp
        }
        do {
            try await db.collection("projects").document(project.id).updateData([
                "checkpoints": updated.map {
                    ["id": $0.id, "title": $0.title, "percentage": $0.percentage, "isCompleted": $0.isCompleted, "orderIndex": $0.orderIndex]
                }
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func saveProjectOrder(_ ordered: [Project]) async {
        let batch = db.batch()
        for (index, project) in ordered.enumerated() {
            batch.updateData(["orderIndex": index], forDocument: db.collection("projects").document(project.id))
        }
        do {
            try await batch.commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteProject(projectId: String) async -> Bool {
        do {
            try await db.collection("projects").document(projectId).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Profile

    @MainActor
    func saveProfile(_ profile: Profile) async -> Bool {
        do {
            try await db.collection("profiles").document(profile.userId)
                .setData(profile.firestoreData, merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func saveAvatarUrl(_ url: String, userUid: String) async {
        do {
            try await db.collection("profiles").document(userUid)
                .setData(["avatarUrl": url], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Registration & Username

    func ensureProfile(uid: String, displayName: String?) async {
        let ref = db.collection("profiles").document(uid)
        do {
            let snap = try await ref.getDocument()
            if !snap.exists {
                try await ref.setData([
                    "fullName": displayName ?? "", "title": "", "bio": "",
                    "location": "", "username": "", "avatarUrl": "", "userId": uid,
                ])
            }
        } catch {
            print("❌ EnsureProfile error: \(error)")
        }
    }

    func isUsernameAvailable(_ username: String) async -> Bool? {
        do {
            let reservation = try await db.collection("usernames").document(username).getDocument()
            if reservation.exists { return false }
            let legacy = try await db.collection("profiles")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            return legacy.documents.isEmpty
        } catch {
            return nil
        }
    }

    func claimUsernameAndCreateProfile(username: String, fullName: String, uid: String) async throws {
        let legacy = try await db.collection("profiles")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        if legacy.documents.contains(where: { $0.documentID != uid }) {
            throw UsernameError.taken
        }

        let usernameRef = db.collection("usernames").document(username)
        let profileRef = db.collection("profiles").document(uid)

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let reservation = try transaction.getDocument(usernameRef)
                if reservation.exists, reservation.data()?["userId"] as? String != uid {
                    errorPointer?.pointee = UsernameError.taken as NSError
                    return nil
                }
                transaction.setData(["userId": uid], forDocument: usernameRef)
                transaction.setData([
                    "fullName": fullName, "title": "", "bio": "", "location": "",
                    "username": username, "avatarUrl": "", "userId": uid,
                ], forDocument: profileRef, merge: true)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }
}

// MARK: - Username Errors

enum UsernameError: LocalizedError {
    case taken

    var errorDescription: String? {
        switch self {
        case .taken: return "This username is already taken."
        }
    }
}
