import Foundation

struct Session: Identifiable, Codable, Equatable {
    let id: String
    let uid: String
    let coachID: String
    let title: String
    let mode: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case coachID = "coach_id"
        case title
        case mode
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let role: String // "user" | "assistant"
    let contentText: String
    let attachments: [Attachment]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case contentText = "content_text"
        case attachments
        case createdAt = "created_at"
    }
    
    var isUser: Bool {
        role == "user"
    }
}

struct Attachment: Codable, Equatable {
    let type: String
    let storagePath: String
    let downloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case storagePath = "storage_path"
        case downloadURL = "download_url"
    }
}

struct ChatDelta: Codable {
    let kind: String // "token" | "final" | "error"
    let token: String?
    let error: String?
}
