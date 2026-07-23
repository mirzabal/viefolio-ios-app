import Foundation

// MARK: - Profile Models (web `types/portfolio.ts` ile birebir)

struct Skill: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var level: Int = 50 // 1-100
    var visible: Bool = true
}

enum SocialLinkType: String, CaseIterable, Codable, Identifiable {
    case github    = "GITHUB"
    case linkedin  = "LINKEDIN"
    case twitter   = "TWITTER"
    case x         = "X"
    case youtube   = "YOUTUBE"
    case instagram = "INSTAGRAM"
    case tiktok    = "TIKTOK"
    case figma     = "FIGMA"
    case behance   = "BEHANCE"
    case dribbble  = "DRIBBBLE"
    case website   = "WEBSITE"
    case custom    = "CUSTOM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github:    return "GitHub"
        case .linkedin:  return "LinkedIn"
        case .twitter:   return "Twitter"
        case .x:         return "X"
        case .youtube:   return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok:    return "TikTok"
        case .figma:     return "Figma"
        case .behance:   return "Behance"
        case .dribbble:  return "Dribbble"
        case .website:   return "Website"
        case .custom:    return "Custom"
        }
    }

    var iconName: String {
        switch self {
        case .github:    return "chevron.left.forwardslash.chevron.right"
        case .linkedin:  return "person.crop.square.fill"
        case .twitter, .x: return "at"
        case .youtube:   return "play.tv.fill"
        case .instagram: return "camera.fill"
        case .tiktok:    return "music.note"
        case .figma:     return "paintbrush.fill"
        case .behance:   return "b.square.fill"
        case .dribbble:  return "basketball.fill"
        case .website:   return "globe"
        case .custom:    return "link"
        }
    }

    init(from rawString: String) {
        self = SocialLinkType(rawValue: rawString.uppercased()) ?? .custom
    }
}

struct SocialLink: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var type: SocialLinkType = .custom
    var title: String = ""
    var url: String = ""
    var imageUrl: String = ""
    var visible: Bool = true
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case developer = "DEVELOPER"
    case designer  = "DESIGNER"
    case creator   = "CREATOR"
    case student   = "STUDENT"

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

struct Profile: Hashable {
    var fullName: String = ""
    var title: String = ""
    var bio: String = ""
    var location: String = ""
    var username: String = ""
    var avatarUrl: String = ""
    var showAvatar: Bool = true
    var socialLinks: [SocialLink] = []
    var showLinks: Bool = true
    var showProjects: Bool = true
    var showSkills: Bool = true
    var skills: [Skill] = []
    var accountType: AccountType?
    var userId: String = ""
}

// MARK: - Firestore Mapping

extension Profile {
    init(userId: String, data: [String: Any]) {
        self.userId = userId
        self.fullName = data["fullName"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.bio = data["bio"] as? String ?? ""
        self.location = data["location"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.avatarUrl = data["avatarUrl"] as? String ?? ""
        self.showAvatar = data["showAvatar"] as? Bool ?? true
        self.showLinks = data["showLinks"] as? Bool ?? true
        self.showProjects = data["showProjects"] as? Bool ?? true
        self.showSkills = data["showSkills"] as? Bool ?? true
        self.accountType = (data["accountType"] as? String).map { AccountType(from: $0) }

        if let array = data["socialLinks"] as? [[String: Any]] {
            self.socialLinks = array.map { l in
                SocialLink(
                    id: l["id"] as? String ?? UUID().uuidString,
                    type: SocialLinkType(from: l["type"] as? String ?? "CUSTOM"),
                    title: l["title"] as? String ?? "",
                    url: l["url"] as? String ?? "",
                    imageUrl: l["imageUrl"] as? String ?? "",
                    visible: l["visible"] as? Bool ?? true
                )
            }
        } else if let legacy = data["socialLinks"] as? [String: String] {
            var migrated: [SocialLink] = []
            if let github = legacy["github"], !github.isEmpty {
                migrated.append(SocialLink(type: .github, title: "GitHub", url: github))
            }
            if let linkedin = legacy["linkedin"], !linkedin.isEmpty {
                migrated.append(SocialLink(type: .linkedin, title: "LinkedIn", url: linkedin))
            }
            if let twitter = legacy["twitter"], !twitter.isEmpty {
                migrated.append(SocialLink(type: .twitter, title: "Twitter", url: twitter))
            }
            self.socialLinks = migrated
        }

        self.skills = ((data["skills"] as? [[String: Any]]) ?? []).map { s in
            Skill(
                id: s["id"] as? String ?? UUID().uuidString,
                name: s["name"] as? String ?? "",
                level: s["level"] as? Int ?? 50,
                visible: s["visible"] as? Bool ?? true
            )
        }
    }

    // Written with merge:true — username, theme and layout stay web-managed
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "fullName": fullName,
            "title": title,
            "bio": bio,
            "location": location,
            "avatarUrl": avatarUrl,
            "showAvatar": showAvatar,
            "socialLinks": socialLinks.map { ["id": $0.id, "type": $0.type.rawValue, "title": $0.title, "url": $0.url, "imageUrl": $0.imageUrl, "visible": $0.visible] },
            "showLinks": showLinks,
            "showProjects": showProjects,
            "showSkills": showSkills,
            "skills": skills.map { ["id": $0.id, "name": $0.name, "level": $0.level, "visible": $0.visible] },
            "userId": userId,
        ]
        if let accountType { data["accountType"] = accountType.rawValue }
        return data
    }
}

extension AccountType {
    init(from rawString: String) {
        self = AccountType(rawValue: rawString.uppercased()) ?? .developer
    }
}
