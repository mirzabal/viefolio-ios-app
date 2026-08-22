import Foundation
import SwiftUI

// MARK: - Project Status Enum

enum ProjectStatus: String, CaseIterable, Codable, Identifiable {
    case inProgress = "IN_PROGRESS"
    case released = "RELEASED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .released:   return "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .inProgress: return "hammer.fill"
        case .released:   return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .inProgress: return .brand
        case .released:   return .green
        }
    }

    init(from rawString: String) {
        switch rawString.uppercased() {
        case "RELEASED", "COMPLETED", "PUBLISHED":
            self = .released
        default:
            self = .inProgress
        }
    }
}
