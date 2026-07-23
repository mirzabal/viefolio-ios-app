import Foundation
import WidgetKit

// MARK: - Insights Models (web `lib/insights.ts` ile aynı şema)

struct VisitStats: Hashable {
    var totalVisits: Int = 0
    var daily: [String: Int] = [:]
    var lastVisitAt: Date?

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var today: Int {
        daily[Self.dayFormatter.string(from: Date())] ?? 0
    }

    func series(days: Int) -> [(date: Date, count: Int)] {
        (0..<days).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (date, daily[Self.dayFormatter.string(from: date)] ?? 0)
        }
    }

    var last7Total: Int {
        series(days: 7).reduce(0) { $0 + $1.count }
    }

    init(totalVisits: Int = 0, daily: [String: Int] = [:], lastVisitAt: Date? = nil) {
        self.totalVisits = totalVisits
        self.daily = daily
        self.lastVisitAt = lastVisitAt
    }
}

struct DeviceSession: Identifiable, Hashable {
    var id: String
    var platform: String   // "IOS" | "WEB"
    var deviceModel: String
    var osVersion: String
    var location: String
    var lastSignIn: Date?

    var systemImage: String {
        switch platform.uppercased() {
        case "IOS": return "iphone"
        case "WEB": return "desktopcomputer"
        default:    return "questionmark.circle"
        }
    }
}

// MARK: - Widget Snapshot (App Group üzerinden widget'a aktarılır)

struct WidgetVisitSnapshot: Codable {
    var total: Int
    var today: Int
    var last7: [Int]
    var username: String
    var updatedAt: Date
}

enum WidgetDataStore {
    static let appGroupId = "group.com.mirzabal.viefolio"
    static let snapshotKey = "visitSnapshot"

    static func save(stats: VisitStats, username: String) {
        let snapshot = WidgetVisitSnapshot(
            total: stats.totalVisits,
            today: stats.today,
            last7: stats.series(days: 7).map(\.count),
            username: username,
            updatedAt: Date()
        )
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
