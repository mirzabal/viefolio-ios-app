import Foundation

// MARK: - Project Link Type Enum

enum ProjectLinkType: String, CaseIterable, Codable, Identifiable {
    case github    = "GITHUB"
    case website   = "WEBSITE"
    case appStore  = "APP_STORE"
    case playStore = "PLAY_STORE"
    case figma     = "FIGMA"
    case behance   = "BEHANCE"
    case dribbble  = "DRIBBBLE"
    case youtube   = "YOUTUBE"
    case instagram = "INSTAGRAM"
    case linkedin  = "LINKEDIN"
    case other     = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github:    return "GitHub"
        case .website:   return "Website"
        case .appStore:  return "App Store"
        case .playStore: return "Play Store"
        case .figma:     return "Figma"
        case .behance:   return "Behance"
        case .dribbble:  return "Dribbble"
        case .youtube:   return "YouTube"
        case .instagram: return "Instagram"
        case .linkedin:  return "LinkedIn"
        case .other:     return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .github:    return "chevron.left.forwardslash.chevron.right"
        case .website:   return "globe"
        case .appStore:  return "app.badge.fill"
        case .playStore: return "play.rectangle.fill"
        case .figma:     return "paintbrush.fill"
        case .behance:   return "b.square.fill"
        case .dribbble:  return "basketball.fill"
        case .youtube:   return "play.tv.fill"
        case .instagram: return "camera.fill"
        case .linkedin:  return "person.crop.square.fill"
        case .other:     return "link"
        }
    }

    init(from rawString: String) {
        let raw = rawString.uppercased()
        switch raw {
        case "WEB":      self = .website
        case "APPSTORE": self = .appStore
        default:         self = ProjectLinkType(rawValue: raw) ?? .other
        }
    }
}
