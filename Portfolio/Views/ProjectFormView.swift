import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - Viefolio Date Helpers

enum ViefolioDate {
    static let present = "present"

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    static func display(_ string: String) -> String {
        if string == present { return "Present" }
        guard let date = formatter.date(from: string) else { return string }
        return displayFormatter.string(from: date)
    }

    static func displayRange(start: String, end: String) -> String {
        let s = start.isEmpty ? "" : display(start)
        let e = end.isEmpty ? "" : display(end)
        if s.isEmpty { return e }
        if e.isEmpty { return s }
        return "\(s) – \(e)"
    }
}

// MARK: - Project Form (Create + Edit)

struct ProjectFormView: View {
    enum Mode {
        case create
        case edit(Project)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationService.self) private var authService
    @State private var firestoreService = FirestoreService.shared

    @State private var project: Project
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var endDateMode: EndDateMode
    @State private var endDate: Date
    @State private var newTech = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImageData: Data?

    @State private var isGenerating = false
    @State private var isGeneratingPercents = false
    @State private var generationError: String?

    @State private var isSaving = false

    enum EndDateMode: String, CaseIterable {
        case none = "None"
        case date = "Date"
        case present = "Present"
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    init(mode: Mode) {
        self.mode = mode
        let initial: Project
        switch mode {
        case .create: initial = Project()
        case .edit(let existing): initial = existing
        }
        _project = State(initialValue: initial)
        _hasStartDate = State(initialValue: !initial.startDate.isEmpty)
        _startDate = State(initialValue: ViefolioDate.formatter.date(from: initial.startDate) ?? Date())
        if initial.endDate == ViefolioDate.present {
            _endDateMode = State(initialValue: .present)
            _endDate = State(initialValue: Date())
        } else if let parsed = ViefolioDate.formatter.date(from: initial.endDate) {
            _endDateMode = State(initialValue: .date)
            _endDate = State(initialValue: parsed)
        } else {
            _endDateMode = State(initialValue: .none)
            _endDate = State(initialValue: Date())
        }
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
                basicsSection
                typeAndIconSection
                datesSection
                imageSection
                linksSection
                techStackSection
                checkpointsSection
            }
            .navigationTitle(isCreate ? "New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(project.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: Sections

    private var basicsSection: some View {
        Section("Project") {
            TextField("Title", text: $project.title)
            TextField("Description", text: $project.description, axis: .vertical)
                .lineLimit(3...6)
            Picker("Status", selection: $project.status) {
                ForEach(ProjectStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var typeAndIconSection: some View {
        Section {
            Picker("Project Type", selection: $project.projectType) {
                ForEach(ProjectType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ProjectIcon.allCases) { icon in
                        Button {
                            project.icon = icon
                        } label: {
                            Image(systemName: icon.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(
                                    project.icon == icon ? Color.indigo.opacity(0.15) : Color(.systemGray6),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(project.icon == icon ? .indigo : .secondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(project.icon == icon ? Color.indigo : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Type & Icon")
        }
    }

    private var datesSection: some View {
        Section("Date Range") {
            Toggle("Start Date", isOn: $hasStartDate.animation())
            if hasStartDate {
                DatePicker("Starts", selection: $startDate, displayedComponents: .date)
            }
            Picker("End Date", selection: $endDateMode.animation()) {
                ForEach(EndDateMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            if endDateMode == .date {
                DatePicker("Ends", selection: $endDate, displayedComponents: .date)
            }
        }
    }

    private var imageSection: some View {
        Section("Cover Image") {
            Toggle("Show image on portfolio", isOn: $project.showImage)

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack {
                    Label(
                        pickedImageData != nil || !project.imageUrl.isEmpty ? "Change Image" : "Choose Image",
                        systemImage: "photo"
                    )
                    Spacer()
                    imageThumbnail
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        pickedImageData = StorageService.preparedJPEG(from: data)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if let data = pickedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if !project.imageUrl.isEmpty, let url = URL(string: project.imageUrl) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray6)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var linksSection: some View {
        Section("Links") {
            ForEach($project.links) { $link in
                HStack {
                    Picker("", selection: $link.type) {
                        ForEach(ProjectLinkType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130, alignment: .leading)
                    TextField("https://…", text: $link.url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .onDelete { project.links.remove(atOffsets: $0) }

            Button {
                project.links.append(ProjectLink())
            } label: {
                Label("Add Link", systemImage: "plus.circle.fill")
            }
        }
    }

    private var techStackSection: some View {
        Section("Tech Stack") {
            if !project.techStack.isEmpty {
                FlowChips(items: project.techStack.map(\.technologyName))
            }
            HStack {
                TextField("e.g. SwiftUI", text: $newTech)
                    .autocorrectionDisabled()
                    .onSubmit(addTech)
                Button(action: addTech) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTech.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !project.techStack.isEmpty {
                Button("Remove Last", role: .destructive) {
                    _ = project.techStack.popLast()
                }
                .font(.caption)
            }
        }
    }

    private var checkpointsSection: some View {
        Section {
            ForEach($project.checkpoints.sorted(by: { $0.wrappedValue.orderIndex < $1.wrappedValue.orderIndex })) { $checkpoint in
                HStack {
                    Button {
                        checkpoint.isCompleted.toggle()
                    } label: {
                        Image(systemName: checkpoint.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkpoint.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    TextField("Checkpoint", text: $checkpoint.title)
                    TextField("%", value: $checkpoint.percentage, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let sorted = project.checkpoints.sorted { $0.orderIndex < $1.orderIndex }
                let ids = offsets.map { sorted[$0].id }
                project.checkpoints.removeAll { ids.contains($0.id) }
            }

            Button {
                let nextIndex = (project.checkpoints.map(\.orderIndex).max() ?? -1) + 1
                project.checkpoints.append(Checkpoint(orderIndex: nextIndex))
            } label: {
                Label("Add Checkpoint", systemImage: "plus.circle.fill")
            }

            Button {
                Task { await generateCheckpoints() }
            } label: {
                HStack {
                    Label("Generate with AI", systemImage: "sparkles")
                    if isGenerating {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isGenerating || project.title.trimmingCharacters(in: .whitespaces).isEmpty)

            if project.checkpoints.count > 1 {
                Button {
                    Task { await generatePercentages() }
                } label: {
                    HStack {
                        Label("Generate Percents with AI", systemImage: "percent")
                        if isGeneratingPercents {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingPercents || project.checkpoints.contains { $0.title.trimmingCharacters(in: .whitespaces).isEmpty })
            }

            if let generationError {
                Text(generationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            HStack {
                Text("Checkpoints")
                Spacer()
                if !project.checkpoints.isEmpty {
                    Text("Total: \(totalPercentage)%")
                        .foregroundStyle(totalPercentage == 100 ? .green : .orange)
                }
            }
        } footer: {
            if !project.checkpoints.isEmpty && totalPercentage != 100 {
                Text("Percentages should add up to 100 so the progress bar is accurate.")
            }
        }
    }

    private var totalPercentage: Int {
        project.checkpoints.reduce(0) { $0 + $1.percentage }
    }

    // MARK: Actions

    private func addTech() {
        let trimmed = newTech.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        project.techStack.append(TechStack(technologyName: trimmed))
        newTech = ""
    }

    private func generateCheckpoints() async {
        isGenerating = true
        generationError = nil
        do {
            let items = try await GeminiService.shared.generateCheckpoints(
                title: project.title,
                description: project.description,
                techStack: project.techStack.map(\.technologyName),
                links: project.links.map { (url: $0.url, type: $0.type.rawValue) }
            )
            project.checkpoints = items.map {
                Checkpoint(title: $0.title, percentage: $0.percentage, isCompleted: $0.isCompleted, orderIndex: $0.orderIndex)
            }
        } catch {
            generationError = error.localizedDescription
        }
        isGenerating = false
    }

    private func generatePercentages() async {
        let sorted = project.checkpoints.sorted { $0.orderIndex < $1.orderIndex }
        isGeneratingPercents = true
        generationError = nil
        do {
            let percents = try await GeminiService.shared.generatePercentages(for: sorted.map(\.title))
            for (i, cp) in sorted.enumerated() {
                if let idx = project.checkpoints.firstIndex(where: { $0.id == cp.id }) {
                    project.checkpoints[idx].percentage = percents[i]
                }
            }
        } catch {
            generationError = error.localizedDescription
        }
        isGeneratingPercents = false
    }

    private func save() async {
        guard let uid = authService.currentUser?.uid else { return }
        isSaving = true
        firestoreService.errorMessage = nil

        project.startDate = hasStartDate ? ViefolioDate.formatter.string(from: startDate) : ""
        switch endDateMode {
        case .none:    project.endDate = ""
        case .date:    project.endDate = ViefolioDate.formatter.string(from: endDate)
        case .present: project.endDate = ViefolioDate.present
        }
        project.userId = uid

        if isCreate {
            if let newId = await firestoreService.createProject(project, userUid: uid) {
                if let imageData = pickedImageData {
                    if let url = try? await StorageService.shared.uploadProjectImage(imageData, userUid: uid, projectId: newId) {
                        await firestoreService.setProjectImageUrl(url, projectId: newId)
                    }
                }
                dismiss()
            }
        } else {
            if let imageData = pickedImageData {
                if let url = try? await StorageService.shared.uploadProjectImage(imageData, userUid: uid, projectId: project.id) {
                    project.imageUrl = url
                }
            }
            if await firestoreService.updateProject(project) {
                dismiss()
            }
        }
        isSaving = false
    }
}
