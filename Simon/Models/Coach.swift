import Foundation

struct Coach: Identifiable, Codable, Equatable {
    let id: String
    let ownerUID: String
    let visibility: String
    let title: String
    let promise: String
    let tags: [String]
    let blueprint: [String: AnyCodable]
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
        case stats
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CoachStats: Codable, Equatable {
    let starts: Int
    let saves: Int
    let upvotes: Int
}

// Helper to handle dynamic JSON
struct AnyCodable: Codable, Equatable {
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
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
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
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}
