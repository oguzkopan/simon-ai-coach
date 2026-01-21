import Foundation
import FirebaseFirestore

// Note: EventAlarm, NotificationTrigger, and DeepLink are defined in
// EventKitManager.swift and NotificationManager.swift respectively

// MARK: - Calendar Event Record

/// Represents a calendar event stored in Firestore
/// Matches the Firestore schema for the `calendar_events` collection
struct CalendarEventRecord: Identifiable, Codable {
    let id: String
    let uid: String
    let coachID: String
    let sessionID: String?
    let toolRunID: String
    
    // Event details
    let title: String
    let startISO: String
    let endISO: String
    let location: String?
    let notes: String?
    let alarms: [EventAlarm]?
    
    // Native app sync
    let eventIdentifier: String?
    let nativeStatus: String
    
    // Metadata
    let status: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, uid
        case coachID = "coach_id"
        case sessionID = "session_id"
        case toolRunID = "tool_run_id"
        case title
        case startISO = "start_iso"
        case endISO = "end_iso"
        case location, notes, alarms
        case eventIdentifier = "event_identifier"
        case nativeStatus = "native_status"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom Codable implementation to handle Firestore Timestamp
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        coachID = try container.decode(String.self, forKey: .coachID)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        toolRunID = try container.decode(String.self, forKey: .toolRunID)
        title = try container.decode(String.self, forKey: .title)
        startISO = try container.decode(String.self, forKey: .startISO)
        endISO = try container.decode(String.self, forKey: .endISO)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        alarms = try container.decodeIfPresent([EventAlarm].self, forKey: .alarms)
        eventIdentifier = try container.decodeIfPresent(String.self, forKey: .eventIdentifier)
        nativeStatus = try container.decode(String.self, forKey: .nativeStatus)
        status = try container.decode(String.self, forKey: .status)
        
        // Handle Firestore Timestamp or Date
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encode(coachID, forKey: .coachID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encode(toolRunID, forKey: .toolRunID)
        try container.encode(title, forKey: .title)
        try container.encode(startISO, forKey: .startISO)
        try container.encode(endISO, forKey: .endISO)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(alarms, forKey: .alarms)
        try container.encodeIfPresent(eventIdentifier, forKey: .eventIdentifier)
        try container.encode(nativeStatus, forKey: .nativeStatus)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Reminder Record

/// Represents a reminder stored in Firestore
/// Matches the Firestore schema for the `reminders` collection
struct ReminderRecord: Identifiable, Codable {
    let id: String
    let uid: String
    let coachID: String
    let sessionID: String?
    let toolRunID: String
    
    // Reminder details
    let title: String
    let notes: String?
    let dueISO: String?
    let priority: Int
    let alarms: [EventAlarm]?
    
    // Native app sync
    let reminderIdentifier: String?
    let nativeStatus: String
    
    // Metadata
    let status: String
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, uid
        case coachID = "coach_id"
        case sessionID = "session_id"
        case toolRunID = "tool_run_id"
        case title, notes
        case dueISO = "due_iso"
        case priority, alarms
        case reminderIdentifier = "reminder_identifier"
        case nativeStatus = "native_status"
        case status
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom Codable implementation to handle Firestore Timestamp
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        coachID = try container.decode(String.self, forKey: .coachID)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        toolRunID = try container.decode(String.self, forKey: .toolRunID)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        dueISO = try container.decodeIfPresent(String.self, forKey: .dueISO)
        priority = try container.decode(Int.self, forKey: .priority)
        alarms = try container.decodeIfPresent([EventAlarm].self, forKey: .alarms)
        reminderIdentifier = try container.decodeIfPresent(String.self, forKey: .reminderIdentifier)
        nativeStatus = try container.decode(String.self, forKey: .nativeStatus)
        status = try container.decode(String.self, forKey: .status)
        
        // Handle Firestore Timestamp or Date for optional completedAt
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .completedAt) {
            completedAt = timestamp.dateValue()
        } else {
            completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        }
        
        // Handle Firestore Timestamp or Date
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encode(coachID, forKey: .coachID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encode(toolRunID, forKey: .toolRunID)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(dueISO, forKey: .dueISO)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(alarms, forKey: .alarms)
        try container.encodeIfPresent(reminderIdentifier, forKey: .reminderIdentifier)
        try container.encode(nativeStatus, forKey: .nativeStatus)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Scheduled Notification Record

/// Represents a scheduled notification stored in Firestore
/// Matches the Firestore schema for the `scheduled_notifications` collection
struct ScheduledNotificationRecord: Identifiable, Codable {
    let id: String
    let uid: String
    let coachID: String
    let sessionID: String?
    let toolRunID: String
    
    // Notification details
    let title: String
    let body: String
    let trigger: NotificationTrigger
    let deepLink: DeepLink?
    
    // Native app sync
    let notificationIdentifier: String
    let nativeStatus: String
    
    // Metadata
    let status: String
    let deliveredAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, uid
        case coachID = "coach_id"
        case sessionID = "session_id"
        case toolRunID = "tool_run_id"
        case title, body, trigger
        case deepLink = "deep_link"
        case notificationIdentifier = "notification_identifier"
        case nativeStatus = "native_status"
        case status
        case deliveredAt = "delivered_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom Codable implementation to handle Firestore Timestamp
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        coachID = try container.decode(String.self, forKey: .coachID)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        toolRunID = try container.decode(String.self, forKey: .toolRunID)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        trigger = try container.decode(NotificationTrigger.self, forKey: .trigger)
        deepLink = try container.decodeIfPresent(DeepLink.self, forKey: .deepLink)
        notificationIdentifier = try container.decode(String.self, forKey: .notificationIdentifier)
        nativeStatus = try container.decode(String.self, forKey: .nativeStatus)
        status = try container.decode(String.self, forKey: .status)
        
        // Handle Firestore Timestamp or Date for optional deliveredAt
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .deliveredAt) {
            deliveredAt = timestamp.dateValue()
        } else {
            deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        }
        
        // Handle Firestore Timestamp or Date
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encode(coachID, forKey: .coachID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encode(toolRunID, forKey: .toolRunID)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(trigger, forKey: .trigger)
        try container.encodeIfPresent(deepLink, forKey: .deepLink)
        try container.encode(notificationIdentifier, forKey: .notificationIdentifier)
        try container.encode(nativeStatus, forKey: .nativeStatus)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Helper Extensions

extension CalendarEventRecord {
    /// Formatted start date for display
    var startDate: Date? {
        ISO8601DateFormatter().date(from: startISO)
    }
    
    /// Formatted end date for display
    var endDate: Date? {
        ISO8601DateFormatter().date(from: endISO)
    }
    
    /// Human-readable status display
    var statusDisplay: String {
        switch status {
        case "upcoming": return "Upcoming"
        case "past": return "Past"
        default: return status.capitalized
        }
    }
    
    /// Human-readable native status display
    var nativeStatusDisplay: String {
        switch nativeStatus {
        case "created": return "Synced"
        case "denied_permission": return "Permission Denied"
        case "failed": return "Sync Failed"
        default: return nativeStatus.capitalized
        }
    }
    
    /// Whether the event is in the past
    var isPast: Bool {
        guard let end = endDate else { return false }
        return end < Date()
    }
    
    /// Whether the event is upcoming
    var isUpcoming: Bool {
        guard let start = startDate else { return false }
        return start > Date()
    }
}

extension ReminderRecord {
    /// Formatted due date for display
    var dueDate: Date? {
        guard let dueISO = dueISO else { return nil }
        return ISO8601DateFormatter().date(from: dueISO)
    }
    
    /// Human-readable status display
    var statusDisplay: String {
        switch status {
        case "pending": return "Pending"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default: return status.capitalized
        }
    }
    
    /// Human-readable native status display
    var nativeStatusDisplay: String {
        switch nativeStatus {
        case "created": return "Synced"
        case "denied_permission": return "Permission Denied"
        case "failed": return "Sync Failed"
        default: return nativeStatus.capitalized
        }
    }
    
    /// Whether the reminder is completed
    var isCompleted: Bool {
        status == "completed"
    }
    
    /// Whether the reminder is overdue
    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }
    
    /// Priority display text
    var priorityDisplay: String {
        switch priority {
        case 0: return "None"
        case 1...3: return "Low"
        case 4...6: return "Medium"
        case 7...9: return "High"
        default: return "Unknown"
        }
    }
}

extension ScheduledNotificationRecord {
    /// Formatted fire date for display (if trigger is at_datetime)
    var fireDate: Date? {
        guard trigger.kind == .atDatetime,
              let fireAtISO = trigger.fireAtISO else { return nil }
        return ISO8601DateFormatter().date(from: fireAtISO)
    }
    
    /// Human-readable status display
    var statusDisplay: String {
        switch status {
        case "scheduled": return "Scheduled"
        case "delivered": return "Delivered"
        case "cancelled": return "Cancelled"
        default: return status.capitalized
        }
    }
    
    /// Human-readable native status display
    var nativeStatusDisplay: String {
        switch nativeStatus {
        case "scheduled": return "Scheduled"
        case "denied": return "Permission Denied"
        case "failed": return "Failed"
        default: return nativeStatus.capitalized
        }
    }
    
    /// Whether the notification is scheduled
    var isScheduled: Bool {
        status == "scheduled"
    }
    
    /// Whether the notification has been delivered
    var isDelivered: Bool {
        status == "delivered"
    }
    
    /// Whether the notification was cancelled
    var isCancelled: Bool {
        status == "cancelled"
    }
    
    /// Trigger description for display
    var triggerDescription: String {
        switch trigger.kind {
        case .atDatetime:
            if let date = fireDate {
                return "At \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return "At specific time"
        case .afterDelay:
            if let delay = trigger.delaySec {
                let minutes = delay / 60
                let hours = minutes / 60
                if hours > 0 {
                    return "After \(hours) hour\(hours == 1 ? "" : "s")"
                } else {
                    return "After \(minutes) minute\(minutes == 1 ? "" : "s")"
                }
            }
            return "After delay"
        }
    }
}
