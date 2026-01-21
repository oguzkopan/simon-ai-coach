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

protocol SimonAPI {
    func listCoaches(tag: String?, featured: Bool?) async throws -> [Coach]
    func getCoach(id: String) async throws -> Coach
    func createCoach(draft: CoachDraft) async throws -> Coach
    func forkCoach(coachId: String) async throws -> Coach
    func publishCoach(coachId: String) async throws -> Coach
    func createSession(coachID: String?) async throws -> Session
    func getSession(id: String) async throws -> SessionDetail
    func streamChat(sessionID: String, userText: String) -> AsyncThrowingStream<SSEEvent, Error>
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
        } catch {
            // User not signed in - continue without auth header for public endpoints
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
        return try decoder.decode([Coach].self, from: data)
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
    
    func streamChat(sessionID: String, userText: String) -> AsyncThrowingStream<SSEEvent, Error> {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/stream")
        let request = ChatStreamRequest(message: userText)
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
        return try decoder.decode([Plan].self, from: data)
    }
    
    func updatePlan(planId: String, updates: [String: Any]) async throws -> Plan {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/plans/\(planId)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError
    case proRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .proRequired:
            return "Pro subscription required"
        }
    }
}
