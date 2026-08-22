import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - Profile Tab

struct ProfileView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var firestoreService = FirestoreService.shared

    @State private var profile = Profile()
    @State private var loadedFromService = false
    @State private var isSaving = false
    @State private var justSaved = false

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarUploading = false

    enum UsernameStatus { case idle, checking, available, taken, invalid }
    @State private var usernameDraft = ""
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var usernameSaving = false
    @State private var usernameError: String?

    private var hasChanges: Bool {
        guard let remote = firestoreService.profile else { return false }
        return profile != remote
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = firestoreService.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                avatarSection
                usernameSection
                aboutSection
                skillsSection
                socialLinksSection
                visibilitySection
            }
            .viefolioBackground()
            .navigationTitle("Profile")
            .refreshable { await firestoreService.refresh() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(justSaved ? "Saved ✓" : "Save") {
                            Task { await save() }
                        }
                        .disabled(!hasChanges)
                    }
                }
            }
            .onChange(of: firestoreService.profile) { _, remote in
                guard let remote else { return }
                if !loadedFromService || !hasChanges {
                    profile = remote
                    usernameDraft = remote.username
                    loadedFromService = true
                }
            }
            .onAppear {
                if let remote = firestoreService.profile, !loadedFromService {
                    profile = remote
                    usernameDraft = remote.username
                    loadedFromService = true
                }
            }
        }
    }

    // MARK: Sections

    private var avatarSection: some View {
        Section {
            HStack(spacing: 16) {
                avatarImage
                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        if avatarUploading {
                            ProgressView()
                        } else {
                            Text("Change Photo")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    Toggle("Show avatar", isOn: $profile.showAvatar)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
            .onChange(of: avatarItem) { _, newItem in
                Task { await uploadAvatar(newItem) }
            }
        }
    }

    private var usernameSection: some View {
        Section {
            HStack(spacing: 8) {
                TextField("username", text: $usernameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: usernameDraft) { _, newValue in
                        let sanitized = sanitizeUsername(newValue)
                        if sanitized != newValue { usernameDraft = sanitized }
                        usernameError = nil
                        scheduleUsernameCheck(sanitized)
                    }
                usernameStatusIcon
            }

            if usernameSaving {
                HStack { ProgressView(); Text("Saving…").foregroundStyle(.secondary) }
            } else if usernameDraft != profile.username && usernameStatus == .available {
                Button("Change username to \(usernameDraft)") {
                    Task { await saveUsername() }
                }
            }

            if let usernameError {
                Label(usernameError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Username")
        } footer: {
            Text(usernameDraft.isEmpty ? "yourname.viefolio.com" : "\(usernameDraft).viefolio.com")
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        switch usernameStatus {
        case .idle, .invalid: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .available: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .taken: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func sanitizeUsername(_ raw: String) -> String {
        String(raw.lowercased().filter { $0.isLowercase || $0.isNumber || $0 == "-" }.prefix(30))
    }

    private func scheduleUsernameCheck(_ value: String) {
        usernameCheckTask?.cancel()
        if value == profile.username { usernameStatus = .idle; return }
        guard value.count >= 2 else {
            usernameStatus = value.isEmpty ? .idle : .invalid
            return
        }
        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let available = await firestoreService.isUsernameAvailable(value)
            guard !Task.isCancelled else { return }
            switch available {
            case .some(true):  usernameStatus = .available
            case .some(false): usernameStatus = .taken
            case .none:        usernameStatus = .idle
            }
        }
    }

    private func saveUsername() async {
        guard usernameDraft != profile.username, !profile.userId.isEmpty else { return }
        usernameSaving = true
        usernameError = nil
        defer { usernameSaving = false }
        do {
            try await firestoreService.changeUsername(
                newUsername: usernameDraft,
                oldUsername: profile.username,
                uid: profile.userId
            )
            profile.username = usernameDraft
        } catch {
            usernameError = (error as? UsernameError)?.errorDescription ?? "Couldn't change username. Try again."
            usernameStatus = .taken
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if !profile.avatarUrl.isEmpty, let url = URL(string: profile.avatarUrl) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color.subtle)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color.hairline)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            TextField("Full Name", text: $profile.fullName)
            TextField("Title (e.g. iOS Developer)", text: $profile.title)
            TextField("Bio", text: $profile.bio, axis: .vertical)
                .lineLimit(3...6)
            TextField("Location", text: $profile.location)
            Picker("Account Type", selection: $profile.accountType) {
                Text("Not set").tag(AccountType?.none)
                ForEach(AccountType.allCases) { type in
                    Text(type.displayName).tag(AccountType?.some(type))
                }
            }
        }
    }

    private var skillsSection: some View {
        Section("Skills") {
            ForEach($profile.skills) { $skill in
                VStack(spacing: 6) {
                    HStack {
                        TextField("Skill name", text: $skill.name)
                        Spacer()
                        Text("\(skill.level)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.brand)
                        Button {
                            skill.visible.toggle()
                        } label: {
                            Image(systemName: skill.visible ? "eye.fill" : "eye.slash")
                                .foregroundStyle(skill.visible ? .brand : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Slider(value: Binding(
                        get: { Double(skill.level) },
                        set: { skill.level = Int($0) }
                    ), in: 1...100, step: 1)
                    .tint(.brand)
                }
                .padding(.vertical, 2)
            }
            .onDelete { profile.skills.remove(atOffsets: $0) }

            Button {
                profile.skills.append(Skill())
            } label: {
                Label("Add Skill", systemImage: "plus.circle.fill")
            }
        }
    }

    private var socialLinksSection: some View {
        Section("Social Links") {
            ForEach($profile.socialLinks) { $link in
                VStack(spacing: 6) {
                    HStack {
                        Picker("", selection: $link.type) {
                            ForEach(SocialLinkType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                        Button {
                            link.visible.toggle()
                        } label: {
                            Image(systemName: link.visible ? "eye.fill" : "eye.slash")
                                .foregroundStyle(link.visible ? .brand : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("Title", text: $link.title)
                        .font(.subheadline)
                    TextField("https://…", text: $link.url)
                        .font(.subheadline)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 2)
            }
            .onDelete { profile.socialLinks.remove(atOffsets: $0) }

            Button {
                profile.socialLinks.append(SocialLink())
            } label: {
                Label("Add Link", systemImage: "plus.circle.fill")
            }
        }
    }

    private var visibilitySection: some View {
        Section {
            Toggle("Show links", isOn: $profile.showLinks)
            Toggle("Show projects", isOn: $profile.showProjects)
            Toggle("Show skills", isOn: $profile.showSkills)
        } header: {
            Text("Portfolio Sections")
        } footer: {
            Text("Hidden sections disappear from your public portfolio immediately.")
        }
    }

    // MARK: Actions

    private func save() async {
        guard !profile.userId.isEmpty else { return }
        isSaving = true
        firestoreService.errorMessage = nil
        let ok = await firestoreService.saveProfile(profile)
        isSaving = false
        if ok {
            justSaved = true
            try? await Task.sleep(for: .seconds(2))
            justSaved = false
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item, let uid = authService.currentUser?.uid else { return }
        avatarUploading = true
        defer { avatarUploading = false }
        firestoreService.errorMessage = nil
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let jpeg = StorageService.preparedJPEG(from: raw, maxDimension: 800) else {
            firestoreService.errorMessage = "Couldn't read that image. Please try another photo."
            return
        }
        do {
            let url = try await StorageService.shared.uploadAvatar(jpeg, userUid: uid)
            profile.avatarUrl = url
            await firestoreService.saveAvatarUrl(url, userUid: uid)
        } catch {
            firestoreService.errorMessage = "Couldn't upload your photo. Check your connection and try again."
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthenticationService())
}
