import SwiftUI

// MARK: - Project Detail

struct ProjectDetailView: View {
    let projectId: String
    @State private var firestoreService = FirestoreService.shared
    @State private var showEditSheet = false

    private var project: Project? {
        firestoreService.projects.first { $0.id == projectId }
    }

    var body: some View {
        Group {
            if let project {
                detail(for: project)
            } else {
                ContentUnavailableView("Project Deleted", systemImage: "trash")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await firestoreService.refresh() }
    }

    private func detail(for project: Project) -> some View {
        List {
            // MARK: Header
            Section {
                HStack(spacing: 14) {
                    Image(systemName: project.icon.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .frame(width: 56, height: 56)
                        .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.title3.weight(.bold))
                        HStack(spacing: 6) {
                            Label(project.status.displayName, systemImage: project.status.iconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(project.status.color)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(project.projectType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !project.startDate.isEmpty || !project.endDate.isEmpty {
                            Text(ViefolioDate.displayRange(start: project.startDate, end: project.endDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Image
            if project.showImage, !project.imageUrl.isEmpty, let url = URL(string: project.imageUrl) {
                Section {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .overlay(ProgressView())
                            .frame(height: 180)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                }
            }

            // MARK: Checkpoints
            if !project.checkpoints.isEmpty {
                Section {
                    ForEach(project.sortedCheckpoints) { checkpoint in
                        Button {
                            Task {
                                await firestoreService.toggleCheckpoint(project: project, checkpointId: checkpoint.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: checkpoint.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checkpoint.isCompleted ? .green : .secondary)
                                Text(checkpoint.title)
                                    .strikethrough(checkpoint.isCompleted, color: .secondary)
                                    .foregroundStyle(checkpoint.isCompleted ? .secondary : .primary)
                                Spacer()
                                Text("\(checkpoint.percentage)%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Checkpoints")
                        Spacer()
                        Text("\(project.progress)% complete")
                            .foregroundStyle(project.status.color)
                    }
                } footer: {
                    ProgressView(value: Double(min(project.progress, 100)), total: 100)
                        .tint(project.status.color)
                        .padding(.top, 4)
                }
            }

            // MARK: Links
            if !project.links.isEmpty {
                Section("Links") {
                    ForEach(project.links) { link in
                        if let url = link.destinationURL {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: link.type.iconName)
                                        .frame(width: 24)
                                        .foregroundStyle(.indigo)
                                    Text(link.type.displayName)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }

            // MARK: Tech Stack
            if !project.techStack.isEmpty {
                Section("Tech Stack") {
                    FlowChips(items: project.techStack.map(\.technologyName))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ProjectFormView(mode: .edit(project))
        }
    }
}

// MARK: - Flow Chips

struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.indigo.opacity(0.1), in: Capsule())
                    .foregroundStyle(.indigo)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout (wraps chips tightly, no fixed-column gaps)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
