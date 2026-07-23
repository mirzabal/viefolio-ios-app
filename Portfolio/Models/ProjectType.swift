import Foundation

// MARK: - Project Type Enum

enum ProjectType: String, CaseIterable, Codable, Identifiable {
    case solo       = "SOLO"
    case team       = "TEAM"
    case personal   = "PERSONAL"
    case freelance  = "FREELANCE"
    case client     = "CLIENT"
    case commission = "COMMISSION"
    case openSource = "OPEN_SOURCE"
    case internship = "INTERNSHIP"
    case academic   = "ACADEMIC"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solo:       return "Solo"
        case .team:       return "Team"
        case .personal:   return "Personal"
        case .freelance:  return "Freelance"
        case .client:     return "Client"
        case .commission: return "Commission"
        case .openSource: return "Open Source"
        case .internship: return "Internship"
        case .academic:   return "Academic"
        }
    }

    init(from rawString: String) {
        self = ProjectType(rawValue: rawString.uppercased()) ?? .solo
    }
}
