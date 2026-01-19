import Foundation

struct System: Identifiable, Codable, Equatable {
    let id: String
    let uid: String
    let title: String
    let checklist: [String]
    let scheduleSuggestion: String
    let metrics: [String]
    let sourceSessionID: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case title
        case checklist
        case scheduleSuggestion = "schedule_suggestion"
        case metrics
        case sourceSessionID = "source_session_id"
        case createdAt = "created_at"
    }
}
