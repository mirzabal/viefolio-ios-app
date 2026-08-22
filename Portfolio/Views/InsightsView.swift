import SwiftUI
import Charts

// MARK: - Insights Tab

struct InsightsView: View {
    @State private var firestoreService = FirestoreService.shared

    private var isLoading: Bool { !firestoreService.statsLoaded }

    private var stats: VisitStats {
        isLoading
        ? VisitStats(totalVisits: 128, daily: Self.placeholderDaily)
        : firestoreService.visitStats
    }

    private static let placeholderDaily: [String: Int] = {
        var daily: [String: Int] = [:]
        for (offset, count) in [4, 9, 3, 12, 7, 15, 6].enumerated() {
            if let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                daily[VisitStats.dayFormatter.string(from: date)] = count
            }
        }
        return daily
    }()

    var body: some View {
        NavigationStack {
            List {
                statCardsSection
                chartSection
                devicesSection
            }
            .viefolioBackground()
            .navigationTitle("Insights")
            .redacted(reason: isLoading ? .placeholder : [])
            .animation(.easeOut(duration: 0.25), value: isLoading)
            .refreshable { await firestoreService.refresh() }
        }
    }

    // MARK: Stat Cards

    private var statCardsSection: some View {
        Section {
            HStack(spacing: 10) {
                statCard(value: stats.totalVisits, label: "Total visits", color: .brand)
                statCard(value: stats.today, label: "Today", color: .green)
                statCard(value: stats.last7Total, label: "Last 7 days", color: .brandSoft)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text("Visits from your own devices aren't counted.")
        }
    }

    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Chart

    private var chartSection: some View {
        Section("Visits · last 7 days") {
            Chart(stats.series(days: 7), id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Visits", item.count)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.brand, .butter], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .padding(.vertical, 8)
        }
    }

    // MARK: Devices

    private var devicesSection: some View {
        Section {
            if !firestoreService.sessionsLoaded {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.subtle)
                            .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iPhone Placeholder")
                            Text("Somewhere, Earth · just now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if firestoreService.sessions.isEmpty {
                Text("No devices recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(firestoreService.sessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.brand)
                            .frame(width: 38, height: 38)
                            .background(Color.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.deviceModel + (session.osVersion.isEmpty ? "" : " · \(session.osVersion)"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if !session.location.isEmpty {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.caption2)
                                    Text(session.location)
                                }
                                if let date = session.lastSignIn {
                                    if !session.location.isEmpty { Text("·") }
                                    Text(date, format: .relative(presentation: .named))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Signed-in devices")
        } footer: {
            Text("Devices where your Viefolio account was opened, with last sign-in time and approximate location.")
        }
    }
}

#Preview {
    InsightsView()
}
