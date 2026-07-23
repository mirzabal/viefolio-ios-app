import Foundation

// MARK: - Project Icon Enum

enum ProjectIcon: String, CaseIterable, Codable, Identifiable {
    case code     = "Code"
    case mobile   = "Mobile"
    case globe    = "Globe"
    case database = "Database"
    case palette  = "Palette"
    case camera   = "Camera"
    case penTool  = "PenTool"
    case video    = "Video"
    case mic      = "Mic"
    case sparkles = "Sparkles"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .mobile:   return "iphone"
        case .globe:    return "globe"
        case .database: return "cylinder.split.1x2.fill"
        case .palette:  return "paintpalette.fill"
        case .camera:   return "camera.fill"
        case .penTool:  return "pencil.and.outline"
        case .video:    return "video.fill"
        case .mic:      return "mic.fill"
        case .sparkles: return "sparkles"
        }
    }

    init(from rawString: String) {
        self = ProjectIcon(rawValue: rawString) ?? .code
    }
}
