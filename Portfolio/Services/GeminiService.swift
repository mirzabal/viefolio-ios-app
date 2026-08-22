import Foundation
import GoogleGenerativeAI

// MARK: - Gemini Service

final class GeminiService {
    
    static let shared = GeminiService()
    
    private let model: GenerativeModel?

    private init() {
        let apiKey = Self.loadAPIKey()

        if let apiKey, !apiKey.isEmpty {
            model = GenerativeModel(
                name: "gemini-flash-latest",
                apiKey: apiKey,
                generationConfig: GenerationConfig(
                    responseMIMEType: "application/json"
                )
            )
        } else {
            model = nil
        }
    }

    // Secrets.plist is gitignored so the key never lands on GitHub
    private static func loadAPIKey() -> String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let secrets = NSDictionary(contentsOf: url) as? [String: Any],
           let key = secrets["GEMINI_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        return Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
    }
    
    // MARK: - Generate Checkpoints with Percentages
    
    func generateCheckpoints(
        title: String,
        description: String,
        techStack: [String],
        links: [(url: String, type: String)] = []
    ) async throws -> [CheckpointItem] {
        guard let model else { throw GeminiError.missingAPIKey }

        let techList = techStack.isEmpty ? "Not specified" : techStack.joined(separator: ", ")
        let linkList = links.isEmpty ? "None" : links.map { "\($0.type): \($0.url)" }.joined(separator: ", ")
        
        let prompt = """
        You are an experienced project mentor. Your audience is broad — developers, designers, creators, and students — so adapt the milestones to whatever kind of project this is (an app, a design, a research paper, a video, a business, an engineering project etc.). Generate 5-8 realistic milestones/checkpoints.

        Project Title: \(title)
        Project Description: \(description)
        Tech Stack / Tools: \(techList)
        Links: \(linkList)

        CRITICAL RULES:
        - Each checkpoint is a short, readable title in Title Case (2-5 words)
        - Use plain spaces between words — never underscores, snake_case, or hyphens joining words
        - Order them logically from project start to finish
        - Assign a "percentage" to each checkpoint representing its share of overall project effort
        - The sum of ALL percentages MUST equal EXACTLY 100
        - Distribute percentages realistically based on effort (heavier phases get more)
        - All checkpoints start as not completed
        - Return ONLY a valid JSON array, no extra text

        JSON Format:
        [
          {"title": "Planning & Research", "isCompleted": false, "orderIndex": 1, "percentage": 10},
          {"title": "Design & Structure", "isCompleted": false, "orderIndex": 2, "percentage": 15},
          {"title": "Core Build", "isCompleted": false, "orderIndex": 3, "percentage": 30}
        ]
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw GeminiError.emptyResponse
        }
        
        guard let data = text.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        var items = try JSONDecoder().decode([CheckpointItem].self, from: data)
        
        let total = items.reduce(0) { $0 + $1.percentage }
        if total != 100 && !items.isEmpty {
            let diff = 100 - total
            items[items.count - 1].percentage += diff
        }
        
        return items
    }

    // MARK: - Generate Percentages for Existing Checkpoints

    /// Given the user's own checkpoint titles (in order), returns a percentage for each,
    /// aligned to the input order and summing to exactly 100.
    func generatePercentages(for titles: [String]) async throws -> [Int] {
        guard let model else { throw GeminiError.missingAPIKey }
        guard titles.count > 1 else { return titles.map { _ in 100 } }

        let list = titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        You are an experienced project mentor. Below is an ordered list of milestones/checkpoints the user wrote for their project. Assign each one a "percentage" representing its share of the overall project effort.

        Checkpoints:
        \(list)

        CRITICAL RULES:
        - Return exactly \(titles.count) percentages, one per checkpoint, in the SAME order as listed.
        - The sum of ALL percentages MUST equal EXACTLY 100.
        - Distribute realistically based on effort (heavier phases get more).
        - Return ONLY a valid JSON array of integers, e.g. [10, 15, 30, 25, 20]. No extra text.
        """

        let response = try await model.generateContent(prompt)
        guard let text = response.text else { throw GeminiError.emptyResponse }
        guard let data = text.data(using: .utf8) else { throw GeminiError.invalidJSON }

        var percentages = try JSONDecoder().decode([Int].self, from: data)
        guard percentages.count == titles.count else { throw GeminiError.invalidJSON }

        let total = percentages.reduce(0, +)
        if total != 100 && !percentages.isEmpty {
            percentages[percentages.count - 1] += 100 - total
        }
        return percentages
    }
}

// MARK: - Models

struct CheckpointItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var percentage: Int
    
    enum CodingKeys: String, CodingKey {
        case title, isCompleted, orderIndex, percentage
    }
    
    init(title: String, isCompleted: Bool = false, orderIndex: Int, percentage: Int = 0) {
        self.title = title
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
        self.percentage = percentage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        self.percentage = try container.decode(Int.self, forKey: .percentage)
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case emptyResponse
    case invalidJSON
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "AI returned an empty response."
        case .invalidJSON: return "Failed to parse AI response."
        case .missingAPIKey: return "Add your Gemini API key (GEMINI_API_KEY) in Info.plist to use AI checkpoints."
        }
    }
}
