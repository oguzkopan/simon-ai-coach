import Foundation
import Combine
import FirebaseFirestore
import OSLog

/// Service for persisting calendar events, reminders, and notifications to Firestore
/// Provides dual-persistence strategy: native iOS apps + Firestore
@MainActor
class EventPersistenceService: ObservableObject {
    nonisolated static let shared = EventPersistenceService()
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.simon.app", category: "EventPersistence")
    
    private let calendarEventsCollection = "calendar_events"
    private let remindersCollection = "reminders"
    private let notificationsCollection = "scheduled_notifications"
    
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    nonisolated private init() {}
    
    func saveCalendarEvent(
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String,
        request: CalendarEventRequest,
        result: CalendarEventResult
    ) async throws -> String {
        let docID = request.idempotencyKey
        
        // Determine status based on start/end dates
        let status = determineEventStatus(startISO: request.startISO, endISO: request.endISO)
        
        let data: [String: Any] = [
            "id": docID,
            "uid": uid,
            "coach_id": coachID,
            "session_id": sessionID as Any,
            "tool_run_id": toolRunID,
            "title": request.title,
            "start_iso": request.startISO,
            "end_iso": request.endISO,
            "location": request.location as Any,
            "notes": request.notes as Any,
            "alarms": encodeAlarms(request.alarms),
            "event_identifier": result.eventID as Any,
            "native_status": result.status.rawValue,
            "status": status,
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        
        try await withRetry(operation: "saveCalendarEvent") {
            try await self.db.collection(self.calendarEventsCollection)
                .document(docID)
                .setData(data)
        }
        
        logger.info("✅ Saved calendar event to Firestore: \(docID)")
        return docID
    }
    
    /// List calendar events with optional filtering
    /// - Parameters:
    ///   - uid: User ID
    ///   - coachID: Optional coach ID filter
    ///   - status: Optional status filter (upcoming, past)
    ///   - limit: Maximum number of results (default 50)
    /// - Returns: Array of calendar event records
    func listCalendarEvents(
        uid: String,
        coachID: String? = nil,
        status: String? = nil,
        limit: Int = 50
    ) async throws -> [CalendarEventRecord] {
        var query: Query = db.collection(calendarEventsCollection)
            .whereField("uid", isEqualTo: uid)
        
        if let coachID = coachID {
            query = query.whereField("coach_id", isEqualTo: coachID)
        }
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status)
        }
        
        query = query
            .order(by: "start_iso", descending: false)
            .limit(to: limit)
        
        let snapshot = try await withRetry(operation: "listCalendarEvents") {
            try await query.getDocuments()
        }
        
        let events = snapshot.documents.compactMap { doc -> CalendarEventRecord? in
            try? doc.data(as: CalendarEventRecord.self)
        }
        
        logger.info("📋 Listed \(events.count) calendar events")
        return events
    }
    
    // MARK: - Reminders
    
    /// Save a reminder to Firestore
    /// - Parameters:
    ///   - uid: User ID
    ///   - coachID: Coach ID that created the reminder
    ///   - sessionID: Optional session ID
    ///   - toolRunID: Tool run ID for audit trail
    ///   - request: Reminder request details
    ///   - result: Result from native Reminders creation
    /// - Returns: Firestore document ID
    func saveReminder(
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String,
        request: ReminderRequest,
        result: ReminderResult
    ) async throws -> String {
        let docID = request.idempotencyKey
        
        let data: [String: Any] = [
            "id": docID,
            "uid": uid,
            "coach_id": coachID,
            "session_id": sessionID as Any,
            "tool_run_id": toolRunID,
            "title": request.title,
            "notes": request.notes as Any,
            "due_iso": request.dueISO as Any,
            "priority": request.priority ?? 0,
            "alarms": encodeAlarms(request.alarms),
            "reminder_identifier": result.reminderID as Any,
            "native_status": result.status.rawValue,
            "status": "pending",
            "completed_at": NSNull(),
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        
        try await withRetry(operation: "saveReminder") {
            try await self.db.collection(self.remindersCollection)
                .document(docID)
                .setData(data)
        }
        
        logger.info("✅ Saved reminder to Firestore: \(docID)")
        return docID
    }
    
    /// List reminders with optional filtering
    /// - Parameters:
    ///   - uid: User ID
    ///   - coachID: Optional coach ID filter
    ///   - status: Optional status filter (pending, completed, cancelled)
    ///   - limit: Maximum number of results (default 50)
    /// - Returns: Array of reminder records
    func listReminders(
        uid: String,
        coachID: String? = nil,
        status: String? = nil,
        limit: Int = 50
    ) async throws -> [ReminderRecord] {
        var query: Query = db.collection(remindersCollection)
            .whereField("uid", isEqualTo: uid)
        
        if let coachID = coachID {
            query = query.whereField("coach_id", isEqualTo: coachID)
        }
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status)
        }
        
        query = query
            .order(by: "created_at", descending: true)
            .limit(to: limit)
        
        let snapshot = try await withRetry(operation: "listReminders") {
            try await query.getDocuments()
        }
        
        let reminders = snapshot.documents.compactMap { doc -> ReminderRecord? in
            try? doc.data(as: ReminderRecord.self)
        }
        
        logger.info("📋 Listed \(reminders.count) reminders")
        return reminders
    }
    
    /// Mark a reminder as complete
    /// - Parameters:
    ///   - id: Reminder document ID
    ///   - uid: User ID (for ownership validation)
    func completeReminder(id: String, uid: String) async throws {
        let docRef = db.collection(remindersCollection).document(id)
        
        // Verify ownership
        let doc = try await docRef.getDocument()
        guard doc.exists,
              let data = doc.data(),
              let docUID = data["uid"] as? String,
              docUID == uid else {
            logger.error("❌ Reminder not found or unauthorized: \(id)")
            throw EventPersistenceError.unauthorized
        }
        
        // Update status
        try await withRetry(operation: "completeReminder") {
            try await docRef.updateData([
                "status": "completed",
                "completed_at": FieldValue.serverTimestamp(),
                "updated_at": FieldValue.serverTimestamp()
            ])
        }
        
        logger.info("✅ Completed reminder: \(id)")
    }
    
    // MARK: - Scheduled Notifications
    
    /// Save a scheduled notification to Firestore
    /// - Parameters:
    ///   - uid: User ID
    ///   - coachID: Coach ID that created the notification
    ///   - sessionID: Optional session ID
    ///   - toolRunID: Tool run ID for audit trail
    ///   - request: Notification request details
    ///   - result: Result from native notification scheduling
    /// - Returns: Firestore document ID
    func saveScheduledNotification(
        uid: String,
        coachID: String,
        sessionID: String?,
        toolRunID: String,
        request: NotificationRequest,
        result: NotificationResult
    ) async throws -> String {
        let docID = request.idempotencyKey
        
        let data: [String: Any] = [
            "id": docID,
            "uid": uid,
            "coach_id": coachID,
            "session_id": sessionID as Any,
            "tool_run_id": toolRunID,
            "title": request.title,
            "body": request.body,
            "trigger": encodeTrigger(request.trigger),
            "deep_link": encodeDeepLink(request.deepLink) as Any,
            "notification_identifier": result.scheduledID,
            "native_status": result.status.rawValue,
            "status": "scheduled",
            "delivered_at": NSNull(),
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        
        try await withRetry(operation: "saveScheduledNotification") {
            try await self.db.collection(self.notificationsCollection)
                .document(docID)
                .setData(data)
        }
        
        logger.info("✅ Saved scheduled notification to Firestore: \(docID)")
        return docID
    }
    
    /// List scheduled notifications with optional filtering
    /// - Parameters:
    ///   - uid: User ID
    ///   - coachID: Optional coach ID filter
    ///   - status: Optional status filter (scheduled, delivered, cancelled)
    ///   - limit: Maximum number of results (default 50)
    /// - Returns: Array of scheduled notification records
    func listScheduledNotifications(
        uid: String,
        coachID: String? = nil,
        status: String? = nil,
        limit: Int = 50
    ) async throws -> [ScheduledNotificationRecord] {
        var query: Query = db.collection(notificationsCollection)
            .whereField("uid", isEqualTo: uid)
        
        if let coachID = coachID {
            query = query.whereField("coach_id", isEqualTo: coachID)
        }
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status)
        }
        
        query = query
            .order(by: "created_at", descending: true)
            .limit(to: limit)
        
        let snapshot = try await withRetry(operation: "listScheduledNotifications") {
            try await query.getDocuments()
        }
        
        let notifications = snapshot.documents.compactMap { doc -> ScheduledNotificationRecord? in
            try? doc.data(as: ScheduledNotificationRecord.self)
        }
        
        logger.info("📋 Listed \(notifications.count) scheduled notifications")
        return notifications
    }
    
    /// Cancel a scheduled notification
    /// - Parameters:
    ///   - id: Notification document ID
    ///   - uid: User ID (for ownership validation)
    func cancelNotification(id: String, uid: String) async throws {
        let docRef = db.collection(notificationsCollection).document(id)
        
        // Verify ownership
        let doc = try await docRef.getDocument()
        guard doc.exists,
              let data = doc.data(),
              let docUID = data["uid"] as? String,
              docUID == uid else {
            logger.error("❌ Notification not found or unauthorized: \(id)")
            throw EventPersistenceError.unauthorized
        }
        
        // Update status
        try await withRetry(operation: "cancelNotification") {
            try await docRef.updateData([
                "status": "cancelled",
                "updated_at": FieldValue.serverTimestamp()
            ])
        }
        
        logger.info("✅ Cancelled notification: \(id)")
    }
    
    // MARK: - Helper Methods
    
    /// Determine event status based on dates
    private func determineEventStatus(startISO: String, endISO: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let endDate = formatter.date(from: endISO) else {
            return "upcoming"
        }
        return endDate < Date() ? "past" : "upcoming"
    }
    
    /// Encode alarms for Firestore
    private func encodeAlarms(_ alarms: [EventAlarm]?) -> [[String: Any]] {
        guard let alarms = alarms else { return [] }
        return alarms.map { ["lead_minutes": $0.leadMinutes] }
    }
    
    /// Encode trigger for Firestore
    private func encodeTrigger(_ trigger: NotificationTrigger) -> [String: Any] {
        var data: [String: Any] = ["kind": trigger.kind.rawValue]
        if let fireAtISO = trigger.fireAtISO {
            data["fire_at_iso"] = fireAtISO
        }
        if let delaySec = trigger.delaySec {
            data["delay_sec"] = delaySec
        }
        return data
    }
    
    /// Encode deep link for Firestore
    private func encodeDeepLink(_ deepLink: DeepLink?) -> [String: Any]? {
        guard let deepLink = deepLink else { return nil as [String: Any]? }
        return ["url": deepLink.url]
    }
    
    /// Retry wrapper for Firestore operations
    private func withRetry<T>(
        operation: String,
        attempt: Int = 1,
        block: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await block()
        } catch {
            // Check if error is retryable (network errors)
            let nsError = error as NSError
            let isNetworkError = nsError.domain == NSURLErrorDomain ||
                                (nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 14)
            
            if isNetworkError && attempt < self.maxRetries {
                logger.warning("⚠️ \(operation) failed (attempt \(attempt)/\(self.maxRetries)), retrying...")
                
                // Exponential backoff
                let delay = self.retryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await self.withRetry(operation: operation, attempt: attempt + 1, block: block)
            }
            
            logger.error("❌ \(operation) failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Errors

enum EventPersistenceError: LocalizedError {
    case unauthorized
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized access to event"
        case .notFound:
            return "Event not found"
        case .invalidData:
            return "Invalid event data"
        }
    }
}
