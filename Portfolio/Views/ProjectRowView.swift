import SwiftUI

// MARK: - Project Row

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    if !project.visible {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(project.description.isEmpty ? "No description" : project.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                statusChip
            }

            Spacer()

            if !project.checkpoints.isEmpty {
                progressRing
            }
        }
        .padding(.vertical, 4)
        .opacity(project.visible ? 1 : 0.55)
    }

    private var statusChip: some View {
        Label(project.status.displayName, systemImage: project.status.iconName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(project.status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(project.status.color.opacity(0.12), in: Capsule())
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(project.progress, 100)) / 100)
                .stroke(project.status.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(project.progress)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .frame(width: 38, height: 38)
    }
}
