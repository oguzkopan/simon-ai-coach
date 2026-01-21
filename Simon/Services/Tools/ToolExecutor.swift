import Foundation
import Combine
import EventKit
import UserNotifications
import OSLog

/// Orchestrates tool execution between backend validation and local execution
@MainActor
final class ToolExecutor: ObservableObject {
    @Published var pendingToolRequest: ToolRequest?
    @Published var isExecuting = false
    @Published var lastError: String?
    
    private let apiClient: SimonAPI
    private let notificationManager: NotificationManager
    private let eventKitManager: EventKitManager
    private let persistenceService: EventPersistenceService
    private let logger = Logger(subsystem: "com.simon.app", category: "ToolExecutor")
    
    init(
        apiClient: SimonAPI,
        notificationManager: NotificationManager? = nil,
        eventKitManager: EventKitManager? = nil,
        persistenceService: EventPersistenceService? = nil
    ) {
        self.apiClient = apiClient
        self.notificationManager = notificationManager ?? .shared
        self.eventKitManager = eventKitManager ?? .shared
        self.persistenceService = persistenceService ?? .shared
    }
    
    // MARK: - Tool Execution Flow
    
    /// Step 1: Request tool execution from backend (validation + token generation)
    func requestExecution(toolID: String, sessionID: String?, input: [String: Any]) async throws -> ToolExecuteResponse {
        isExecuting = true
        lastError = nil
        
        defer { isExecuting = false }
        
        let request = ToolExecuteRequest(
            toolID: toolID,
            sessionID: sessionID,
            input: input
        )
        
        do {
            let response = try await apiClient.executeToolRequest(request)
            return response
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Step 2: Execute tool locally (after user confirmation)
    func executeLocally(
        toolID: String,
        input: [String: Any],
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String
    ) async throws -> [String: Any] {
        switch toolID {
        case "local_notification_schedule":
            return try await executeNotification(
                input: input,
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID
            )
            
        case "calendar_event_create":
            return try await executeCalendarEvent(
                input: input,
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID
            )
            
        case "reminder_create":
            return try await executeReminder(
                input: input,
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID
            )
            
        case "share_sheet_export":
            return try await executeExport(input: input)
            
        default:
            throw ToolExecutorError.unsupportedTool(toolID)
        }
    }
    
    /// Step 3: Report result back to backend
    func reportResult(
        toolRunID: String,
        executionToken: String,
        status: String,
        output: [String: Any]? = nil,
        error: String? = nil
    ) async throws {
        let request = ToolResultRequest(
            toolRunID: toolRunID,
            executionToken: executionToken,
            status: status,
            output: output,
            error: error
        )
        
        try await apiClient.submitToolResult(request)
    }
    
    // MARK: - Local Tool Implementations
    
    private func executeNotification(
        input: [String: Any],
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String
    ) async throws -> [String: Any] {
        guard let title = input["title"] as? String,
              let body = input["body"] as? String,
              let triggerData = input["trigger"] as? [String: Any],
              let idempotencyKey = input["idempotency_key"] as? String else {
            throw ToolExecutorError.invalidInput("Missing required notification fields")
        }
        
        // Request permission
        let granted = try await notificationManager.requestPermission()
        guard granted else {
            throw ToolExecutorError.permissionDenied("Notification permission denied")
        }
        
        // Parse trigger
        let trigger: NotificationTrigger
        if let kind = triggerData["kind"] as? String {
            switch kind {
            case "at_datetime":
                guard let fireAtISO = triggerData["fire_at_iso"] as? String else {
                    throw ToolExecutorError.invalidInput("Missing fire_at_iso")
                }
                trigger = NotificationTrigger(
                    kind: .atDatetime,
                    fireAtISO: fireAtISO,
                    delaySec: nil
                )
                
            case "after_delay":
                guard let delaySec = triggerData["delay_sec"] as? Int else {
                    throw ToolExecutorError.invalidInput("Missing delay_sec")
                }
                trigger = NotificationTrigger(
                    kind: .afterDelay,
                    fireAtISO: nil,
                    delaySec: delaySec
                )
                
            default:
                throw ToolExecutorError.invalidInput("Unknown trigger kind: \(kind)")
            }
        } else {
            throw ToolExecutorError.invalidInput("Missing trigger kind")
        }
        
        // Parse deep link
        var deepLink: DeepLink?
        if let deepLinkData = input["deep_link"] as? [String: Any],
           let url = deepLinkData["url"] as? String {
            deepLink = DeepLink(url: url)
        }
        
        // Schedule notification (native app)
        let request = NotificationRequest(
            title: title,
            body: body,
            trigger: trigger,
            deepLink: deepLink,
            idempotencyKey: idempotencyKey
        )
        
        let result = try await notificationManager.scheduleNotification(request: request)
        
        // Persist to Firestore (dual-write)
        var recordID: String?
        do {
            recordID = try await persistenceService.saveScheduledNotification(
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID,
                request: request,
                result: result
            )
            logger.info("✅ Notification persisted to Firestore: \(recordID ?? "unknown")")
        } catch {
            // Log error but don't fail the tool execution
            logger.error("⚠️ Failed to persist notification to Firestore: \(error.localizedDescription)")
        }
        
        return [
            "scheduled_id": result.scheduledID,
            "status": result.status.rawValue,
            "record_id": recordID ?? ""
        ]
    }
    
    private func executeCalendarEvent(
        input: [String: Any],
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String
    ) async throws -> [String: Any] {
        guard let title = input["title"] as? String,
              let startISO = input["start_iso"] as? String,
              let endISO = input["end_iso"] as? String,
              let idempotencyKey = input["idempotency_key"] as? String else {
            throw ToolExecutorError.invalidInput("Missing required calendar event fields")
        }
        
        // Request permission
        let granted = try await eventKitManager.requestCalendarPermission()
        guard granted else {
            throw ToolExecutorError.permissionDenied("Calendar permission denied")
        }
        
        // Parse alarms
        var alarms: [EventAlarm] = []
        if let alarmsData = input["alarms"] as? [[String: Any]] {
            alarms = alarmsData.compactMap { alarmData in
                guard let leadMinutes = alarmData["lead_minutes"] as? Int else { return nil }
                return EventAlarm(leadMinutes: leadMinutes)
            }
        }
        
        // Create event (native app)
        let request = CalendarEventRequest(
            title: title,
            startISO: startISO,
            endISO: endISO,
            location: input["location"] as? String,
            notes: input["notes"] as? String,
            alarms: alarms,
            idempotencyKey: idempotencyKey
        )
        
        let result = try await eventKitManager.createCalendarEvent(request: request)
        
        // Persist to Firestore (dual-write)
        var recordID: String?
        do {
            recordID = try await persistenceService.saveCalendarEvent(
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID,
                request: request,
                result: result
            )
            logger.info("✅ Calendar event persisted to Firestore: \(recordID ?? "unknown")")
        } catch {
            // Log error but don't fail the tool execution
            logger.error("⚠️ Failed to persist calendar event to Firestore: \(error.localizedDescription)")
        }
        
        return [
            "event_id": result.eventID ?? "",
            "status": result.status.rawValue,
            "record_id": recordID ?? ""
        ]
    }
    
    private func executeReminder(
        input: [String: Any],
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String
    ) async throws -> [String: Any] {
        guard let title = input["title"] as? String,
              let idempotencyKey = input["idempotency_key"] as? String else {
            throw ToolExecutorError.invalidInput("Missing required reminder fields")
        }
        
        // Request permission
        let granted = try await eventKitManager.requestRemindersPermission()
        guard granted else {
            throw ToolExecutorError.permissionDenied("Reminders permission denied")
        }
        
        // Parse alarms
        var alarms: [EventAlarm] = []
        if let alarmsData = input["alarms"] as? [[String: Any]] {
            alarms = alarmsData.compactMap { alarmData in
                guard let leadMinutes = alarmData["lead_minutes"] as? Int else { return nil }
                return EventAlarm(leadMinutes: leadMinutes)
            }
        }
        
        // Create reminder (native app)
        let request = ReminderRequest(
            title: title,
            notes: input["notes"] as? String,
            dueISO: input["due_iso"] as? String,
            priority: input["priority"] as? Int ?? 0,
            alarms: alarms,
            idempotencyKey: idempotencyKey
        )
        
        let result = try await eventKitManager.createReminder(request: request)
        
        // Persist to Firestore (dual-write)
        var recordID: String?
        do {
            recordID = try await persistenceService.saveReminder(
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: toolRunID,
                request: request,
                result: result
            )
            logger.info("✅ Reminder persisted to Firestore: \(recordID ?? "unknown")")
        } catch {
            // Log error but don't fail the tool execution
            logger.error("⚠️ Failed to persist reminder to Firestore: \(error.localizedDescription)")
        }
        
        return [
            "reminder_id": result.reminderID ?? "",
            "status": result.status.rawValue,
            "record_id": recordID ?? ""
        ]
    }
    
    private func executeExport(input: [String: Any]) async throws -> [String: Any] {
        guard let _ = input["format"] as? String,
              let payloadRef = input["payload_ref"] as? [String: Any],
              let _ = payloadRef["type"] as? String,
              let _ = payloadRef["id"] as? String else {
            throw ToolExecutorError.invalidInput("Missing required export fields")
        }
        
        // For now, return success - actual export implementation would go here
        // This would integrate with ExportManager
        
        return [
            "status": "exported"
        ]
    }
    
    // MARK: - Complete Flow Helper
    
    /// Complete flow: request → execute → report
    func executeToolWithConfirmation(
        toolID: String,
        sessionID: String?,
        input: [String: Any],
        uid: String,
        coachID: String,
        onConfirm: @escaping () async -> Bool
    ) async throws {
        // Step 1: Request execution from backend
        let response = try await requestExecution(
            toolID: toolID,
            sessionID: sessionID,
            input: input
        )
        
        // Step 2: Wait for user confirmation
        let confirmed = await onConfirm()
        
        if !confirmed {
            // Report declined
            try await reportResult(
                toolRunID: response.toolRunID,
                executionToken: response.executionToken ?? "",
                status: "declined"
            )
            return
        }
        
        // Step 3: Execute locally with context parameters
        do {
            let output = try await executeLocally(
                toolID: toolID,
                input: input,
                uid: uid,
                coachID: coachID,
                sessionID: sessionID,
                toolRunID: response.toolRunID
            )
            
            // Step 4: Report success
            try await reportResult(
                toolRunID: response.toolRunID,
                executionToken: response.executionToken ?? "",
                status: "executed",
                output: output
            )
        } catch {
            // Step 4: Report failure
            try await reportResult(
                toolRunID: response.toolRunID,
                executionToken: response.executionToken ?? "",
                status: "failed",
                error: error.localizedDescription
            )
            throw error
        }
    }
}

// MARK: - Supporting Types

struct ToolRequest {
    let toolID: String
    let sessionID: String?
    let input: [String: Any]
}

struct ToolExecuteRequest: Encodable {
    let toolID: String
    let sessionID: String?
    let input: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case toolID = "tool_id"
        case sessionID = "session_id"
        case input
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolID, forKey: .toolID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encode(AnyCodableDict(input), forKey: .input)
    }
}

struct ToolExecuteResponse: Decodable {
    let toolRunID: String
    let status: String
    let executionToken: String?
    let output: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case toolRunID = "tool_run_id"
        case status
        case executionToken = "execution_token"
        case output
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolRunID = try container.decode(String.self, forKey: .toolRunID)
        status = try container.decode(String.self, forKey: .status)
        executionToken = try container.decodeIfPresent(String.self, forKey: .executionToken)
        if let anyDict = try? container.decodeIfPresent(AnyCodableDict.self, forKey: .output) {
            output = anyDict.value
        } else {
            output = nil
        }
    }
}

struct ToolResultRequest: Encodable {
    let toolRunID: String
    let executionToken: String
    let status: String
    let output: [String: Any]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case toolRunID = "tool_run_id"
        case executionToken = "execution_token"
        case status
        case output
        case error
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolRunID, forKey: .toolRunID)
        try container.encode(executionToken, forKey: .executionToken)
        try container.encode(status, forKey: .status)
        if let output = output {
            try container.encode(AnyCodableDict(output), forKey: .output)
        }
        try container.encodeIfPresent(error, forKey: .error)
    }
}

// Helper for encoding/decoding [String: Any]
struct AnyCodableDict: Codable {
    let value: [String: Any]
    
    init(_ value: [String: Any]) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodableValue].self)
        value = dict.mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let dict = value.mapValues { AnyCodableValue($0) }
        try container.encode(dict)
    }
}

struct AnyCodableValue: Codable {
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
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
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
            try container.encode(array.map { AnyCodableValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

enum ToolExecutorError: LocalizedError {
    case unsupportedTool(String)
    case invalidInput(String)
    case permissionDenied(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTool(let toolID):
            return "Unsupported tool: \(toolID)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}
