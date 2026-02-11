import Foundation
import Combine

struct MomentStartResponse: Codable {
    let sessionId: String
    let coachId: String?
    let coachName: String
    let firstMessage: String?
}

struct UserContextData: Codable {
    var values: [String]
    var goals: [String]
    var constraints: [String]
    var currentProjects: [String]
}

struct AvatarGenerationResponse: Codable {
    let imageUrl: String?  // Public URL to the uploaded image
    let imageData: String  // Base64 encoded (for backward compatibility)
    let mimeType: String
}

protocol SimonAPI {
    func listCoaches(tag: String?, featured: Bool?) async throws -> [Coach]
    func getCoach(id: String) async throws -> Coach
    func createCoach(draft: CoachDraft) async throws -> Coach
    func createCoach(title: String, promise: String, tags: [String], coachSpec: CoachSpec?, avatarData: Data?, avatarURL: String?) async throws -> Coach
    func generateCoachAvatar(prompt: String, specialty: String, style: String) async throws -> AvatarGenerationResponse
    func forkCoach(coachId: String) async throws -> Coach
    func publishCoach(coachId: String) async throws -> Coach
    func saveCoach(coachId: String) async throws
    func unsaveCoach(coachId: String) async throws
    func getSavedCoaches() async throws -> [Coach]
    func createSession(coachID: String?) async throws -> Session
    func getSession(id: String) async throws -> SessionDetail
    func streamChat(sessionID: String, userText: String, attachments: [Attachment]?, voiceOverEnabled: Bool) -> AsyncThrowingStream<SSEEvent, Error>
    func listSessions(limit: Int?) async throws -> [Session]
    func listSystems() async throws -> [System]
    func createSystem(system: System) async throws -> System
    func getSystem(id: String) async throws -> System
    func deleteSystem(id: String) async throws
    func startMoment(prompt: String) async throws -> MomentStartResponse
    func getContext() async throws -> UserContextData
    func updateContext(context: UserContextData) async throws
    func updateContextPreference(includeContext: Bool) async throws
    func deleteAllUserData() async throws
    func executeToolRequest(_ request: ToolExecuteRequest) async throws -> ToolExecuteResponse
    func submitToolResult(_ request: ToolResultRequest) async throws
    
    // Plan endpoints
    func createPlan(coachId: String, plan: Plan) async throws -> Plan
    func listPlans(status: String?, limit: Int?) async throws -> [Plan]
    func updatePlan(planId: String, updates: [String: Any]) async throws -> Plan
    
    // Event endpoints
    func getCalendarEvents(coachID: String?, status: String?, limit: Int?, offset: Int?) async throws -> [CalendarEventRecord]
    func getReminders(coachID: String?, status: String?, limit: Int?, offset: Int?) async throws -> [ReminderRecord]
    func getScheduledNotifications(coachID: String?, status: String?, limit: Int?, offset: Int?) async throws -> [ScheduledNotificationRecord]
    func completeReminder(id: String) async throws -> ReminderRecord
    func cancelNotification(id: String) async throws -> ScheduledNotificationRecord
    
    // Voice endpoints
    func getVoices() async throws -> [ElevenLabsVoice]
    func getVoice(id: String) async throws -> ElevenLabsVoice
    func getVoicePresets() async throws -> [VoicePreset]
    
    // Voice chat streaming
    func streamVoiceChat(sessionID: String, audioData: Data, text: String?, attachments: [Attachment]?) -> AsyncThrowingStream<SSEEvent, Error>
}

struct SessionDetail: Codable {
    let session: Session
    let messages: [Message]
}

final class SimonAPIClient: SimonAPI {
    static let shared = SimonAPIClient(baseURL: URL(string: "https://simon-api-pl6ewfkpvq-uc.a.run.app")!)
    
    let baseURL: URL
    private let session: URLSession
    private let authManager = AuthenticationManager.shared
    
    init(baseURL: URL) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Auth Helper
    
    private func addAuthHeader(to request: inout URLRequest) async throws {
        // Try to get token, but don't fail if user is not signed in
        do {
            let token = try await authManager.idToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Added auth token to request")
        } catch {
            // User not signed in - continue without auth header for public endpoints
            print("⚠️ No auth token available: \(error)")
        }
    }
    
    // MARK: - Coaches
    
    func listCoaches(tag: String? = nil, featured: Bool? = nil) async throws -> [Coach] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/coaches"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let tag = tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let featured = featured {
            queryItems.append(URLQueryItem(name: "featured", value: String(featured)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth header if available (optional for public browsing)
        try? await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let coaches = try decoder.decode([Coach].self, from: data)
        
        // Debug: Print avatar URLs
        for coach in coaches {
            if let avatarUrl = coach.avatarUrl {
                print("✅ Coach '\(coach.title)' has avatar: \(avatarUrl)")
            } else {
                print("⚠️ Coach '\(coach.title)' has NO avatar URL")
            }
        }
        
        return coaches
    }
    
    func getCoach(id: String) async throws -> Coach {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/\(id)"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth header if available (optional for public browsing)
        try? await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Coach.self, from: data)
    }
    
    func createCoach(draft: CoachDraft) async throws -> Coach {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let body: [String: Any] = [
            "title": draft.name,
            "promise": draft.promise,
            "blueprint": draft.toBlueprint()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Coach.self, from: data)
    }
    
    func createCoach(title: String, promise: String, tags: [String], coachSpec: CoachSpec?, avatarData: Data?, avatarURL: String?) async throws -> Coach {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        var body: [String: Any] = [
            "title": title,
            "promise": promise,
            "tags": tags
        ]
        
        if let coachSpec = coachSpec {
            let encoder = JSONEncoder()
            if let specData = try? encoder.encode(coachSpec),
               let specDict = try? JSONSerialization.jsonObject(with: specData) as? [String: Any] {
                body["coachSpec"] = specDict
            }
        }
        
        // Include avatar URL if provided
        if let avatarURL = avatarURL, !avatarURL.isEmpty {
            body["avatar_url"] = avatarURL
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorDict["error"] as? String {
                throw APIError.serverError(errorMessage)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Coach.self, from: data)
    }
    
    func generateCoachAvatar(prompt: String, specialty: String, style: String) async throws -> AvatarGenerationResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/generate-avatar"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Increase timeout to 60 seconds for image generation
        try await addAuthHeader(to: &request)
        
        let body: [String: Any] = [
            "prompt": prompt,
            "specialty": specialty,
            "style": style
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AvatarGenerationResponse.self, from: data)
    }
    
    func forkCoach(coachId: String) async throws -> Coach {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/\(coachId)/fork"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Coach.self, from: data)
    }
    
    func publishCoach(coachId: String) async throws -> Coach {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/\(coachId)/publish"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 402 {
            throw APIError.proRequired
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Coach.self, from: data)
    }
    
    func saveCoach(coachId: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/\(coachId)/save"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    func unsaveCoach(coachId: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/\(coachId)/save"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    func getSavedCoaches() async throws -> [Coach] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/coaches/saved/list"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Coach].self, from: data)
    }
    
    // MARK: - Sessions
    
    func createSession(coachID: String?) async throws -> Session {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let body: [String: String?] = [
            "coach_id": coachID
        ]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Session.self, from: data)
    }
    
    func getSession(id: String) async throws -> SessionDetail {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions/\(id)"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionDetail.self, from: data)
    }
    
    func listSessions(limit: Int? = nil) async throws -> [Session] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/sessions"), resolvingAgainstBaseURL: false)!
        
        if let limit = limit {
            components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        }
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Session].self, from: data)
    }
    
    // MARK: - Chat Streaming
    
    func streamChat(sessionID: String, userText: String, attachments: [Attachment]? = nil, voiceOverEnabled: Bool = false) -> AsyncThrowingStream<SSEEvent, Error> {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/stream")
        
        // Get user's timezone and local time
        let timezone = TimeZone.current.identifier
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let localTime = formatter.string(from: Date())
        
        let request = ChatStreamRequest(
            userText: userText,
            attachments: attachments,
            userTimezone: timezone,
            userLocalTime: localTime,
            voiceOverEnabled: voiceOverEnabled
        )
        let sseManager = SSEStreamManager()
        return sseManager.connect(url: url, request: request)
    }
    
    // MARK: - Systems
    
    func listSystems() async throws -> [System] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/systems"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([System].self, from: data)
    }
    
    func createSystem(system: System) async throws -> System {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/systems"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(system)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(System.self, from: data)
    }
    
    func getSystem(id: String) async throws -> System {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/systems/\(id)"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(System.self, from: data)
    }
    
    func deleteSystem(id: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/systems/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Moments
    
    func startMoment(prompt: String) async throws -> MomentStartResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/moments/start"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let body = ["prompt": prompt]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 402 {
            throw APIError.proRequired
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MomentStartResponse.self, from: data)
    }
    
    // MARK: - Context
    
    func getContext() async throws -> UserContextData {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/context"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UserContextData.self, from: data)
    }
    
    func updateContext(context: UserContextData) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/context"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(context)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    func updateContextPreference(includeContext: Bool) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/context/preference"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let body = ["include_context": includeContext]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - User Data
    
    func deleteAllUserData() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/me"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Plans
    
    func createPlan(coachId: String, plan: Plan) async throws -> Plan {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/plans"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(plan)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Plan.self, from: data)
    }
    
    func listPlans(status: String? = nil, limit: Int? = nil) async throws -> [Plan] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/plans"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        print("🔍 Fetching plans from: \(components.url!.absoluteString)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 Plans API response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ Plans API error body: \(errorBody)")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let plans = try decoder.decode([Plan].self, from: data)
        
        print("✅ Decoded \(plans.count) plans")
        
        return plans
    }
    
    func updatePlan(planId: String, updates: [String: Any]) async throws -> Plan {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/plans/\(planId)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        // Wrap updates in an "updates" field as expected by the backend
        let body: [String: Any] = ["updates": updates]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // Backend returns {"status": "updated"}, so we need to fetch the updated plan
        // For now, we'll fetch all plans and find the one we updated
        let plans = try await listPlans(status: nil, limit: 100)
        guard let updatedPlan = plans.first(where: { $0.id == planId }) else {
            throw APIError.invalidResponse
        }
        
        return updatedPlan
    }
    
    // MARK: - Tool Execution
    
    func executeToolRequest(_ toolRequest: ToolExecuteRequest) async throws -> ToolExecuteResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/tools/execute"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(toolRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Don't use automatic snake_case conversion since ToolExecuteResponse has explicit CodingKeys
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ToolExecuteResponse.self, from: data)
    }
    
    func submitToolResult(_ toolResult: ToolResultRequest) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/tools/result"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(toolResult)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Events
    
    func getCalendarEvents(
        coachID: String? = nil,
        status: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [CalendarEventRecord] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/events/calendar"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let coachID = coachID {
            queryItems.append(URLQueryItem(name: "coach_id", value: coachID))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CalendarEventRecord].self, from: data)
    }
    
    func getReminders(
        coachID: String? = nil,
        status: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [ReminderRecord] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/events/reminders"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let coachID = coachID {
            queryItems.append(URLQueryItem(name: "coach_id", value: coachID))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ReminderRecord].self, from: data)
    }
    
    func getScheduledNotifications(
        coachID: String? = nil,
        status: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [ScheduledNotificationRecord] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/v1/events/notifications"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let coachID = coachID {
            queryItems.append(URLQueryItem(name: "coach_id", value: coachID))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ScheduledNotificationRecord].self, from: data)
    }
    
    func completeReminder(id: String) async throws -> ReminderRecord {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/events/reminders/\(id)/complete"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReminderRecord.self, from: data)
    }
    
    func cancelNotification(id: String) async throws -> ScheduledNotificationRecord {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/events/notifications/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScheduledNotificationRecord.self, from: data)
    }
    
    // MARK: - Voice
    
    func getVoices() async throws -> [ElevenLabsVoice] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/voices"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        do {
            let voicesResponse = try decoder.decode(VoicesResponse.self, from: data)
            return voicesResponse.voices
        } catch {
            print("❌ Failed to decode voices response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Response data: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
    
    func getVoice(id: String) async throws -> ElevenLabsVoice {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/voices/\(id)"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ElevenLabsVoice.self, from: data)
    }
    
    func getVoicePresets() async throws -> [VoicePreset] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/voices/presets/list"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        do {
            let presetsResponse = try decoder.decode(VoicePresetsResponse.self, from: data)
            return presetsResponse.presets
        } catch {
            print("❌ Failed to decode presets response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Response data: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
    
    // MARK: - Voice Chat Streaming
    
    func streamVoiceChat(sessionID: String, audioData: Data, text: String? = nil, attachments: [Attachment]? = nil) -> AsyncThrowingStream<SSEEvent, Error> {
        // Use the regular chat endpoint - it now handles audio!
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/stream")
        
        // Get user's timezone and local time
        let timezone = TimeZone.current.identifier
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let localTime = formatter.string(from: Date())
        
        // Encode audio data as base64
        let audioBase64 = audioData.base64EncodedString()
        
        // Build request payload - same format as regular chat
        var payload: [String: Any] = [
            "user_text": text ?? "🎤 Voice message",
            "audio_data": audioBase64,
            "user_timezone": timezone,
            "user_local_time": localTime
        ]
        
        if let attachments = attachments {
            let attachmentDicts = attachments.map { att -> [String: Any] in
                var dict: [String: Any] = [
                    "type": att.type,
                    "download_url": att.downloadURL
                ]
                if let mimeType = att.mimeType {
                    dict["mime_type"] = mimeType
                }
                return dict
            }
            payload["attachments"] = attachmentDicts
        }
        
        let sseManager = SSEStreamManager()
        return sseManager.connectWithPayload(url: url, payload: payload)
    }
}


enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case proRequired
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "The data couldn't be read because it is missing."
        case .proRequired:
            return "Pro subscription required"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        }
    }
}
