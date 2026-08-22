import WidgetKit
import SwiftUI

// MARK: - Snapshot (ana uygulamanın App Group'a yazdığı veri)

struct VisitSnapshot: Codable {
    var total: Int
    var today: Int
    var last7: [Int]
    var username: String
    var updatedAt: Date

    static let placeholder = VisitSnapshot(
        total: 128, today: 6, last7: [4, 9, 3, 12, 7, 15, 6],
        username: "you", updatedAt: .now
    )

    static func load() -> VisitSnapshot? {
        guard let defaults = UserDefaults(suiteName: "group.com.mirzabal.viefolio"),
              let data = defaults.data(forKey: "visitSnapshot") else { return nil }
        return try? JSONDecoder().decode(VisitSnapshot.self, from: data)
    }
}

// MARK: - Timeline

struct VisitEntry: TimelineEntry {
    let date: Date
    let snapshot: VisitSnapshot?
}

struct VisitProvider: TimelineProvider {
    func placeholder(in context: Context) -> VisitEntry {
        VisitEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (VisitEntry) -> Void) {
        completion(VisitEntry(date: .now, snapshot: VisitSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VisitEntry>) -> Void) {
        let entry = VisitEntry(date: .now, snapshot: VisitSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Views

struct VisitsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VisitEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium: medium(snapshot)
                default: small(snapshot)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            Color.wSurface
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(.wBrand)
            Text("Open Viefolio to load your stats")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func small(_ s: VisitSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                Text("VISITS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
            }
            .foregroundStyle(.wBrand)

            Spacer(minLength: 0)

            Text("\(s.total)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(s.today == 1 ? "1 visit today" : "\(s.today) visits today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ s: VisitSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                    Text("PORTFOLIO VISITS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                }
                .foregroundStyle(.wBrand)

                Spacer(minLength: 0)

                Text("\(s.total)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("\(s.today) today · \(s.last7.reduce(0, +)) this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let peak = max(1, s.last7.max() ?? 1)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(s.last7.enumerated()), id: \.offset) { _, count in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            count > 0
                            ? AnyShapeStyle(LinearGradient(colors: [.wBrand, .wButter], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.wSubtle)
                        )
                        .frame(width: 10, height: max(5, CGFloat(count) / CGFloat(peak) * 52))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct VisitsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ViefolioVisitsWidget", provider: VisitProvider()) { entry in
            VisitsWidgetView(entry: entry)
        }
        .configurationDisplayName("Portfolio Visits")
        .description("See how many people visited your Viefolio portfolio.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PortfolioWidgetBundle: WidgetBundle {
    var body: some Widget {
        VisitsWidget()
    }
}

// MARK: - Viefolio palette (mirrors Portfolio/Models/Theme.swift)

extension ShapeStyle where Self == Color {
    static var wBrand: Color { Color(red: 0.004, green: 0.243, blue: 0.216) }   // #013e37
    static var wButter: Color { Color(red: 1.0, green: 0.937, blue: 0.702) }    // #ffefb3
    static var wSurface: Color { Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.008, green: 0.184, blue: 0.165, alpha: 1)
        : UIColor(red: 0.992, green: 0.984, blue: 0.953, alpha: 1) }) }         // #fdfbf3 / #012f2a
    static var wSubtle: Color { Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.227, blue: 0.200, alpha: 1)
        : UIColor(red: 0.945, green: 0.933, blue: 0.882, alpha: 1) }) }         // #f1eee1
}
