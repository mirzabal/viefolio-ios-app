import Foundation
import FirebaseFirestore

// MARK: - Project Models (web `types/portfolio.ts` ile birebir)

struct ProjectLink: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var type: ProjectLinkType = .website
    var url: String = ""

    var destinationURL: URL? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://" + trimmed)
    }
}

struct TechStack: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var technologyName: String = ""
}

struct Checkpoint: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String = ""
    var percentage: Int = 0
    var isCompleted: Bool = false
    var orderIndex: Int = 0
}

struct Project: Identifiable, Hashable {
    var id: String = ""
    var title: String = ""
    var description: String = ""
    var status: ProjectStatus = .inProgress
    var imageUrl: String = ""
    var showImage: Bool = false
    var icon: ProjectIcon = .code
    var projectType: ProjectType = .solo
    var startDate: String = ""
    var endDate: String = ""
    var links: [ProjectLink] = []
    var techStack: [TechStack] = []
    var checkpoints: [Checkpoint] = []
    var userId: String = ""
    var orderIndex: Int = 0
    var visible: Bool = true

    var progress: Int {
        guard !checkpoints.isEmpty else { return 0 }
        return checkpoints.filter(\.isCompleted).reduce(0) { $0 + $1.percentage }
    }

    var sortedCheckpoints: [Checkpoint] {
        checkpoints.sorted { $0.orderIndex < $1.orderIndex }
    }
}

// MARK: - Firestore Mapping

extension Project {
    private static func dateString(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let ts = value as? Timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.string(from: ts.dateValue())
        }
        return ""
    }

    // Tolerant of docs written by older app versions (Timestamp dates, coverImageUrl, etc.)
    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = (data["title"] as? String) ?? (data["name"] as? String) ?? "Untitled"
        self.description = data["description"] as? String ?? ""
        self.status = ProjectStatus(from: data["status"] as? String ?? "IN_PROGRESS")
        self.imageUrl = (data["imageUrl"] as? String) ?? (data["coverImageUrl"] as? String) ?? ""
        self.showImage = data["showImage"] as? Bool ?? false
        self.icon = ProjectIcon(from: data["icon"] as? String ?? "Code")
        self.projectType = ProjectType(from: data["projectType"] as? String ?? "SOLO")
        self.startDate = Self.dateString(data["startDate"])
        self.endDate = Self.dateString(data["endDate"])
        self.userId = data["userId"] as? String ?? ""
        self.orderIndex = data["orderIndex"] as? Int ?? 0
        self.visible = data["visible"] as? Bool ?? true

        self.links = ((data["links"] as? [[String: Any]]) ?? []).map { l in
            ProjectLink(
                id: l["id"] as? String ?? UUID().uuidString,
                type: ProjectLinkType(from: l["type"] as? String ?? "WEBSITE"),
                url: (l["url"] as? String) ?? (l["link"] as? String) ?? ""
            )
        }
        self.techStack = ((data["techStack"] as? [Any]) ?? []).map { t in
            if let s = t as? String { return TechStack(technologyName: s) }
            let dict = t as? [String: Any] ?? [:]
            return TechStack(
                id: dict["id"] as? String ?? UUID().uuidString,
                technologyName: (dict["technologyName"] as? String) ?? (dict["name"] as? String) ?? ""
            )
        }
        self.checkpoints = ((data["checkpoints"] as? [[String: Any]]) ?? []).enumerated().map { idx, cp in
            Checkpoint(
                id: cp["id"] as? String ?? "cp-\(idx)",
                title: cp["title"] as? String ?? "",
                percentage: cp["percentage"] as? Int ?? 0,
                isCompleted: cp["isCompleted"] as? Bool ?? false,
                orderIndex: cp["orderIndex"] as? Int ?? idx
            )
        }
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "description": description,
            "status": status.rawValue,
            "imageUrl": imageUrl,
            "showImage": showImage,
            "icon": icon.rawValue,
            "projectType": projectType.rawValue,
            "startDate": startDate,
            "endDate": endDate,
            "techStack": techStack.map { ["id": $0.id, "technologyName": $0.technologyName] },
            "checkpoints": checkpoints
                .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ["id": $0.id, "title": $0.title, "percentage": $0.percentage, "isCompleted": $0.isCompleted, "orderIndex": $0.orderIndex] },
            "links": links.map { ["id": $0.id, "type": $0.type.rawValue, "url": $0.url] },
            "userId": userId,
        ]
    }
}
