import Foundation

// MARK: - ElevenLabs Voice Models

struct ElevenLabsVoice: Codable, Identifiable {
    let voiceID: String
    let name: String
    let category: String
    let description: String?
    let previewURL: String?
    let labels: [String: String]?
    let settings: VoiceSettings?
    
    var id: String { voiceID }
    
    enum CodingKeys: String, CodingKey {
        case voiceID = "voice_id"
        case name
        case category
        case description
        case previewURL = "preview_url"
        case labels
        case settings
    }
    
    // Custom decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceID = try container.decode(String.self, forKey: .voiceID)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "general"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        previewURL = try container.decodeIfPresent(String.self, forKey: .previewURL)
        labels = try container.decodeIfPresent([String: String].self, forKey: .labels)
        settings = try container.decodeIfPresent(VoiceSettings.self, forKey: .settings)
    }
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarityBoost: Double
    let style: Double?
    let useSpeakerBoost: Bool?
    
    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case useSpeakerBoost = "use_speaker_boost"
    }
    
    // Custom decoder to provide defaults for missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stability = try container.decodeIfPresent(Double.self, forKey: .stability) ?? 0.5
        similarityBoost = try container.decodeIfPresent(Double.self, forKey: .similarityBoost) ?? 0.75
        style = try container.decodeIfPresent(Double.self, forKey: .style)
        useSpeakerBoost = try container.decodeIfPresent(Bool.self, forKey: .useSpeakerBoost)
    }
    
    // Standard init for creating instances
    init(stability: Double, similarityBoost: Double, style: Double? = nil, useSpeakerBoost: Bool? = nil) {
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.useSpeakerBoost = useSpeakerBoost
    }
}

struct VoicePreset: Codable, Identifiable {
    let name: String
    let description: String
    let settings: VoiceSettings
    
    var id: String { name }
}

struct VoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

struct VoicePresetsResponse: Codable {
    let presets: [VoicePreset]
}

// MARK: - Voice Selection State

enum VoiceSelectionMode {
    case preset
    case custom
}

struct SelectedVoice {
    let voiceID: String
    let voiceName: String
    let settings: VoiceSettings
    let presetName: String?
}
