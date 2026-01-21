import Foundation
import Combine

// MARK: - SSE Event Types

enum SSEEvent {
    case streamOpen(StreamOpenPayload)
    case messageDelta(MessageDeltaPayload)
    case messageFinal(MessageFinalPayload)
    case cardNextActions(NextActionsCardPayload)
    case cardPlan(PlanCardPayload)
    case cardWeeklyReview(WeeklyReviewCardPayload)
    case toolRequest(ToolRequestPayload)
    case toolStatus(ToolStatusPayload)
    case policyNotice(PolicyNoticePayload)
    case error(ErrorPayload)
    case streamDone(StreamDonePayload)
    case unknown(String, [String: Any])
}

// MARK: - Payload Structs

struct StreamOpenPayload: Codable {
    let sessionId: String
    let serverTimeIso: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case serverTimeIso = "server_time_iso"
    }
}

struct MessageDeltaPayload: Codable {
    let role: String
    let delta: String
}

struct MessageFinalPayload: Codable {
    let messageId: String
    let role: String
    let text: String
    let renderHints: RenderHints?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case role
        case text
        case renderHints = "render_hints"
    }
    
    struct RenderHints: Codable {
        let maxCards: Int?
        
        enum CodingKeys: String, CodingKey {
            case maxCards = "max_cards"
        }
    }
}

struct NextActionsCardPayload: Codable {
    let schema: String
    let items: [NextActionItem]
    
    struct NextActionItem: Codable {
        let id: String
        let title: String
        let durationMin: Int
        let energy: String
        let when: WhenInfo
        let confidence: Double?
        
        enum CodingKeys: String, CodingKey {
            case id, title
            case durationMin = "duration_min"
            case energy, when, confidence
        }
        
        struct WhenInfo: Codable {
            let kind: String
            let startIso: String?
            let endIso: String?
            
            enum CodingKeys: String, CodingKey {
                case kind
                case startIso = "start_iso"
                case endIso = "end_iso"
            }
        }
    }
}

struct PlanCardPayload: Codable {
    let schema: String
    let plan: PlanInfo
    
    struct PlanInfo: Codable {
        let title: String
        let objective: String
        let horizon: String
        let milestones: [Milestone]
        let nextActions: [String]
        
        enum CodingKeys: String, CodingKey {
            case title, objective, horizon, milestones
            case nextActions = "next_actions"
        }
        
        struct Milestone: Codable {
            let label: String
            let dueDateHint: String?
            let successMetric: String?
            
            enum CodingKeys: String, CodingKey {
                case label
                case dueDateHint = "due_date_hint"
                case successMetric = "success_metric"
            }
        }
    }
}

struct WeeklyReviewCardPayload: Codable {
    let schema: String
    let review: ReviewInfo
    
    struct ReviewInfo: Codable {
        let wins: [String]
        let misses: [String]
        let rootCauses: [String]
        let nextWeekFocus: [String]
        let commitments: [String]
        
        enum CodingKeys: String, CodingKey {
            case wins, misses
            case rootCauses = "root_causes"
            case nextWeekFocus = "next_week_focus"
            case commitments
        }
    }
}

struct ToolRequestPayload: Codable {
    let requestId: String
    let toolId: String
    let tool: String
    let requiresConfirmation: Bool
    let reason: String
    let input: [String: SSEAnyCodable]
    let payload: [String: SSEAnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case toolId = "tool_id"
        case tool
        case requiresConfirmation = "requires_confirmation"
        case reason
        case input
        case payload
    }
}

struct ToolStatusPayload: Codable {
    let requestId: String
    let status: String
    let executionToken: String?
    let expiresInSec: Int?
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case executionToken = "execution_token"
        case expiresInSec = "expires_in_sec"
    }
}

struct PolicyNoticePayload: Codable {
    let kind: String
    let message: String
}

struct ErrorPayload: Codable {
    let code: String
    let message: String
}

struct StreamDonePayload: Codable {
    let status: String
}

// MARK: - SSEAnyCodable Helper

struct SSEAnyCodable: Codable {
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
        } else if let array = try? container.decode([SSEAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: SSEAnyCodable].self) {
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
            try container.encode(array.map { SSEAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { SSEAnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - SSE Stream Manager

enum SSEError: Error {
    case invalidResponse
    case connectionFailed
    case parsingError(String)
    case timeout
    case rateLimitExceeded
    case unauthorized
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .connectionFailed:
            return "Failed to connect to server"
        case .parsingError(let message):
            return "Error parsing response: \(message)"
        case .timeout:
            return "Request timed out"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Authentication failed. Please sign in again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class SSEStreamManager {
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    /// Connect to SSE endpoint and return an async stream of events with automatic reconnection
    func connect(url: URL, request: ChatStreamRequest, retryCount: Int = 0) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    print("📡 SSE: Connecting to \(url)")
                    print("📡 SSE: Request message: \(request.message)")
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.timeoutInterval = 300 // 5 minutes
                    
                    // Get Firebase ID token
                    print("📡 SSE: Getting Firebase ID token...")
                    let token = try await AuthenticationManager.shared.idToken()
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    print("📡 SSE: Token obtained")
                    
                    // Encode request body
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    urlRequest.httpBody = try encoder.encode(request)
                    print("📡 SSE: Request body encoded")
                    
                    // Start streaming
                    print("📡 SSE: Starting URLSession.bytes...")
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ SSE: Invalid response type")
                        throw SSEError.invalidResponse
                    }
                    
                    print("📡 SSE: HTTP Status: \(httpResponse.statusCode)")
                    print("📡 SSE: Response headers: \(httpResponse.allHeaderFields)")
                    
                    // Handle HTTP errors
                    switch httpResponse.statusCode {
                    case 200...299:
                        print("✅ SSE: Connection successful")
                        break // Success
                    case 401:
                        print("❌ SSE: Unauthorized")
                        throw SSEError.unauthorized
                    case 429:
                        print("❌ SSE: Rate limit exceeded")
                        throw SSEError.rateLimitExceeded
                    default:
                        print("❌ SSE: Invalid response status: \(httpResponse.statusCode)")
                        throw SSEError.invalidResponse
                    }
                    
                    var currentEvent: String?
                    var currentData: String?
                    var currentID: String?
                    
                    print("📡 SSE: Starting to read stream...")
                    
                    for try await line in bytes.lines {
                        print("📡 SSE: Received line: \(line.isEmpty ? "<empty>" : line)")
                        
                        if line.isEmpty {
                            // Event complete - parse and emit
                            if let eventType = currentEvent, let data = currentData {
                                print("📡 SSE: Parsing event - type: \(eventType), data: \(data)")
                                do {
                                    let event = try self.parseEvent(type: eventType, data: data, id: currentID)
                                    print("📡 SSE: Yielding event: \(eventType)")
                                    continuation.yield(event)
                                    
                                    // Close stream on completion or error
                                    if case .streamDone = event {
                                        print("📡 SSE: Stream done, finishing")
                                        continuation.finish()
                                        return
                                    } else if case .error = event {
                                        print("📡 SSE: Error event, finishing")
                                        continuation.finish()
                                        return
                                    }
                                } catch {
                                    print("❌ SSE: Error parsing event: \(error)")
                                }
                            }
                            
                            // Reset for next event
                            currentEvent = nil
                            currentData = nil
                            currentID = nil
                        } else if line.hasPrefix("id:") {
                            currentID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                            print("📡 SSE: Event ID: \(currentID ?? "nil")")
                        } else if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            print("📡 SSE: Event type: \(currentEvent ?? "nil")")
                        } else if line.hasPrefix("data:") {
                            let dataLine = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if currentData == nil {
                                currentData = dataLine
                            } else {
                                currentData! += "\n" + dataLine
                            }
                            print("📡 SSE: Data accumulated: \(currentData?.prefix(100) ?? "nil")...")
                        } else if line.hasPrefix(":") {
                            // Comment (keep-alive), ignore
                            print("📡 SSE: Keep-alive comment")
                            continue
                        }
                    }
                    
                    print("📡 SSE: Stream ended normally")
                    continuation.finish()
                } catch let error as SSEError {
                    // Handle SSE-specific errors
                    if retryCount < self.maxRetries && self.shouldRetry(error) {
                        print("SSE connection failed, retrying (\(retryCount + 1)/\(self.maxRetries))...")
                        try? await Task.sleep(nanoseconds: UInt64(self.retryDelay * 1_000_000_000))
                        
                        // Reconnect with incremented retry count
                        let retryStream = self.connect(url: url, request: request, retryCount: retryCount + 1)
                        for try await event in retryStream {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                } catch {
                    // Handle other errors
                    let sseError = SSEError.networkError(error)
                    if retryCount < self.maxRetries {
                        print("Network error, retrying (\(retryCount + 1)/\(self.maxRetries))...")
                        try? await Task.sleep(nanoseconds: UInt64(self.retryDelay * 1_000_000_000))
                        
                        let retryStream = self.connect(url: url, request: request, retryCount: retryCount + 1)
                        for try await event in retryStream {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: sseError)
                    }
                }
            }
        }
    }
    
    /// Determine if an error should trigger a retry
    private func shouldRetry(_ error: SSEError) -> Bool {
        switch error {
        case .connectionFailed, .timeout, .networkError:
            return true
        case .unauthorized, .rateLimitExceeded, .invalidResponse, .parsingError:
            return false
        }
    }
    
    /// Parse SSE event based on type
    private func parseEvent(type: String, data: String, id: String?) throws -> SSEEvent {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let jsonData = data.data(using: .utf8) else {
            throw SSEError.parsingError("Invalid UTF-8 data")
        }
        
        switch type {
        case "stream.open":
            let payload = try decoder.decode(StreamOpenPayload.self, from: jsonData)
            return .streamOpen(payload)
            
        case "message.delta":
            let payload = try decoder.decode(MessageDeltaPayload.self, from: jsonData)
            return .messageDelta(payload)
            
        case "message.final":
            let payload = try decoder.decode(MessageFinalPayload.self, from: jsonData)
            return .messageFinal(payload)
            
        case "card.next_actions":
            let payload = try decoder.decode(NextActionsCardPayload.self, from: jsonData)
            return .cardNextActions(payload)
            
        case "card.plan":
            let payload = try decoder.decode(PlanCardPayload.self, from: jsonData)
            return .cardPlan(payload)
            
        case "card.weekly_review":
            let payload = try decoder.decode(WeeklyReviewCardPayload.self, from: jsonData)
            return .cardWeeklyReview(payload)
            
        case "tool.request":
            let payload = try decoder.decode(ToolRequestPayload.self, from: jsonData)
            return .toolRequest(payload)
            
        case "tool.status":
            let payload = try decoder.decode(ToolStatusPayload.self, from: jsonData)
            return .toolStatus(payload)
            
        case "policy.notice":
            let payload = try decoder.decode(PolicyNoticePayload.self, from: jsonData)
            return .policyNotice(payload)
            
        case "error":
            let payload = try decoder.decode(ErrorPayload.self, from: jsonData)
            return .error(payload)
            
        case "stream.done":
            let payload = try decoder.decode(StreamDonePayload.self, from: jsonData)
            return .streamDone(payload)
            
        default:
            // Unknown event type - try to parse as generic JSON
            if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return .unknown(type, dict)
            } else {
                throw SSEError.parsingError("Unknown event type: \(type)")
            }
        }
    }
}

// MARK: - Chat Stream Request

struct ChatStreamRequest: Codable {
    let message: String
}
