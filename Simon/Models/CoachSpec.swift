//
//  CoachSpec.swift
//  Simon
//
//  Created by Kiro Agent
//  Structured specification for coach behavior, style, and capabilities
//

import Foundation

/// CoachSpec defines the structured specification for a coach's behavior, style, and capabilities
struct CoachSpec: Codable, Equatable {
    let version: String
    let identity: Identity
    let style: Style
    let methods: Methods
    let policies: Policies
    let toolsAllowed: ToolsAllowed
    let outputs: Outputs
    
    enum CodingKeys: String, CodingKey {
        case version
        case identity
        case style
        case methods
        case policies
        case toolsAllowed = "tools_allowed"
        case outputs
    }
}

// MARK: - Identity

/// Identity defines the coach's identity and positioning
struct Identity: Codable, Equatable {
    let name: String
    let tagline: String
    let niche: String
    let audience: [String]
    let problemStatements: [String]
    let outcomes: [String]
    let languages: [String]
    let persona: Persona
}

/// Persona defines the coach's personality and boundaries
struct Persona: Codable, Equatable {
    let archetype: String
    let voice: String
    let boundaries: [String]
}

// MARK: - Style

/// Style defines the coach's communication style and formatting preferences
struct Style: Codable, Equatable {
    let tone: String
    let verbosity: String
    let formatting: Formatting
    let interactionRules: InteractionRules
}

/// Formatting defines formatting constraints for coach responses
struct Formatting: Codable, Equatable {
    let maxBullets: Int
    let maxSentencesPerParagraph: Int
    let alwaysEndWith: [String]
    let useEmoji: String
    let allowedMarkdown: [String]
}

/// InteractionRules defines behavioral rules for coach interactions
struct InteractionRules: Codable, Equatable {
    let askOneQuestionAtATime: Bool
    let confirmBeforeScheduling: Bool
    let avoidMotivationalFluff: Bool
    let reflectUserLanguage: Bool
}

// MARK: - Methods

/// Methods defines the coaching frameworks and protocols
struct Methods: Codable, Equatable {
    let frameworks: [Framework]
    let defaultProtocols: DefaultProtocols
}

/// Framework defines a coaching framework with steps and triggers
struct Framework: Codable, Equatable {
    let id: String
    let name: String
    let goal: String
    let steps: [String]
    let whenToUse: [String]
}

/// DefaultProtocols defines default coaching protocols for different session types
struct DefaultProtocols: Codable, Equatable {
    let quickNudge: Protocol
    let deepSession: Protocol
}

/// Protocol defines a coaching protocol with template or phases
struct Protocol: Codable, Equatable {
    let template: [String]?
    let phases: [String]?
}

// MARK: - Policies

/// Policies defines safety, privacy, and refusal policies
struct Policies: Codable, Equatable {
    let refusals: Refusals
    let privacy: Privacy
    let safety: Safety
}

/// Refusals defines what the coach should refuse to provide advice on
struct Refusals: Codable, Equatable {
    let medical: Bool
    let legal: Bool
    let financialAdvice: String
    let selfHarm: String
    
    enum CodingKeys: String, CodingKey {
        case medical
        case legal
        case financialAdvice = "financial_advice"
        case selfHarm = "self_harm"
    }
}

/// Privacy defines privacy and data handling policies
struct Privacy: Codable, Equatable {
    let storeSensitiveMemory: Bool
    let redactPatterns: [String]
    let userControls: [String]
}

/// Safety defines safety constraints for coach behavior
struct Safety: Codable, Equatable {
    let noManipulation: Bool
    let noGuilt: Bool
    let noShaming: Bool
}

// MARK: - Tools

/// ToolsAllowed defines which tools the coach can use
struct ToolsAllowed: Codable, Equatable {
    let clientTools: [String]
    let serverTools: [String]
    let requiresUserConfirmation: [String]
    
    enum CodingKeys: String, CodingKey {
        case clientTools = "client_tools"
        case serverTools = "server_tools"
        case requiresUserConfirmation = "requires_user_confirmation"
    }
}

// MARK: - Outputs

/// Outputs defines the structured output schemas and rendering hints
struct Outputs: Codable, Equatable {
    let schemas: OutputSchemas
    let renderingHints: RenderingHints
    
    enum CodingKeys: String, CodingKey {
        case schemas
        case renderingHints = "rendering_hints"
    }
}

/// OutputSchemas defines JSON schemas for structured outputs
struct OutputSchemas: Codable, Equatable {
    let plan: SchemaDefinition
    let nextAction: SchemaDefinition
    let weeklyReview: SchemaDefinition
    
    enum CodingKeys: String, CodingKey {
        case plan = "Plan"
        case nextAction = "NextAction"
        case weeklyReview = "WeeklyReview"
    }
}

/// SchemaDefinition defines a JSON schema for validation
/// Properties are stored as a generic dictionary that can be decoded/encoded dynamically
struct SchemaDefinition: Codable, Equatable {
    let type: String
    let required: [String]?
    
    // Using a custom type to handle dynamic properties
    private let propertiesData: [String: PropertyValue]?
    
    var properties: [String: Any]? {
        propertiesData?.mapValues { $0.value }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case required
        case propertiesData = "properties"
    }
    
    init(type: String, required: [String]? = nil, properties: [String: Any]? = nil) {
        self.type = type
        self.required = required
        self.propertiesData = properties?.mapValues { PropertyValue($0) }
    }
    
    static func == (lhs: SchemaDefinition, rhs: SchemaDefinition) -> Bool {
        return lhs.type == rhs.type &&
               lhs.required == rhs.required &&
               String(describing: lhs.propertiesData) == String(describing: rhs.propertiesData)
    }
}

/// PropertyValue wraps any value for schema properties
struct PropertyValue: Codable, Equatable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([PropertyValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: PropertyValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { PropertyValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { PropertyValue($0) })
        default:
            try container.encodeNil()
        }
    }
    
    static func == (lhs: PropertyValue, rhs: PropertyValue) -> Bool {
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}

/// RenderingHints provides hints for how to render structured outputs
struct RenderingHints: Codable, Equatable {
    let primaryCard: String
    let maxCardsPerResponse: Int
}

// MARK: - Helper Types
// Note: CoachAnyCodable is defined in Coach.swift and reused here

// MARK: - CoachWithSpec

/// CoachWithSpec extends the Coach model to include CoachSpec
/// This matches the Go CoachWithSpec type for backward compatibility
struct CoachWithSpec: Codable {
    let id: String
    let ownerUID: String
    let visibility: String
    let title: String
    let promise: String
    let tags: [String]
    private let blueprintData: [String: BlueprintValue]? // Deprecated, kept for backward compatibility
    let coachSpec: CoachSpec?
    private let statsData: StatsData
    let createdAt: Date
    let updatedAt: Date
    
    var blueprint: [String: Any]? {
        blueprintData?.mapValues { $0.value }
    }
    
    var stats: (uses: Int, saves: Int, ratingsAvg: Double) {
        (statsData.uses, statsData.saves, statsData.ratingsAvg)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerUID = "owner_uid"
        case visibility
        case title
        case promise
        case tags
        case blueprintData = "blueprint"
        case coachSpec
        case statsData = "stats"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// BlueprintValue wraps any value for blueprint properties
struct BlueprintValue: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([BlueprintValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: BlueprintValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { BlueprintValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { BlueprintValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// StatsData holds coach statistics
struct StatsData: Codable {
    let uses: Int
    let saves: Int
    let ratingsAvg: Double
    
    enum CodingKeys: String, CodingKey {
        case uses
        case saves
        case ratingsAvg = "ratings_avg"
    }
}
