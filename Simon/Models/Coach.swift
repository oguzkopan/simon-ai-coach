import Foundation

struct Coach: Identifiable, Codable {
    let id: String
    let ownerUID: String
    let visibility: String
    let title: String
    let promise: String
    let tags: [String]
    let blueprint: [String: CoachAnyCodable]?  // Deprecated, kept for backward compatibility
    let coachSpec: CoachSpec?
    let stats: CoachStats
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerUID = "owner_uid"
        case visibility
        case title
        case promise
        case tags
        case blueprint
        case coachSpec
        case stats
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Equatable Conformance
extension Coach: Equatable {
    static func == (lhs: Coach, rhs: Coach) -> Bool {
        return lhs.id == rhs.id &&
               lhs.ownerUID == rhs.ownerUID &&
               lhs.visibility == rhs.visibility &&
               lhs.title == rhs.title &&
               lhs.promise == rhs.promise &&
               lhs.tags == rhs.tags &&
               lhs.stats == rhs.stats &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.coachSpec == rhs.coachSpec &&
               compareBlueprintOptionals(lhs.blueprint, rhs.blueprint)
    }
    
    private static func compareBlueprintOptionals(_ lhs: [String: CoachAnyCodable]?, _ rhs: [String: CoachAnyCodable]?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.some(let l), .some(let r)):
            guard l.count == r.count else { return false }
            for (key, value) in l {
                guard let rhsValue = r[key], value == rhsValue else { return false }
            }
            return true
        default:
            return false
        }
    }
}

struct CoachStats: Codable, Equatable {
    let starts: Int
    let saves: Int
    let upvotes: Int
}

// Helper to handle dynamic JSON
struct CoachAnyCodable: Codable, Equatable {
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
        } else if let array = try? container.decode([CoachAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: CoachAnyCodable].self) {
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
            try container.encode(array.map { CoachAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { CoachAnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    static func == (lhs: CoachAnyCodable, rhs: CoachAnyCodable) -> Bool {
        // Simple equality check
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}
