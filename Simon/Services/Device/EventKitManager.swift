import Foundation
import Combine
import EventKit

// MARK: - Calendar Event Models

struct CalendarEventRequest: Codable {
    let title: String
    let startISO: String
    let endISO: String
    let location: String?
    let notes: String?
    let alarms: [EventAlarm]?
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case startISO = "start_iso"
        case endISO = "end_iso"
        case location, notes, alarms
        case idempotencyKey = "idempotency_key"
    }
}

struct EventAlarm: Codable {
    let leadMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case leadMinutes = "lead_minutes"
    }
}

struct CalendarEventResult: Codable {
    let eventID: String?
    let status: EventStatus
    
    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case status
    }
    
    enum EventStatus: String, Codable {
        case created
        case deniedPermission = "denied_permission"
        case failed
    }
}

// MARK: - Reminder Models

struct ReminderRequest: Codable {
    let title: String
    let notes: String?
    let dueISO: String?
    let priority: Int?
    let alarms: [EventAlarm]?
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case title, notes
        case dueISO = "due_iso"
        case priority, alarms
        case idempotencyKey = "idempotency_key"
    }
}

struct ReminderResult: Codable {
    let reminderID: String?
    let status: ReminderStatus
    
    enum CodingKeys: String, CodingKey {
        case reminderID = "reminder_id"
        case status
    }
    
    enum ReminderStatus: String, Codable {
        case created
        case deniedPermission = "denied_permission"
        case failed
    }
}

// MARK: - EventKit Errors

enum EventKitError: LocalizedError {
    case calendarPermissionDenied
    case reminderPermissionDenied
    case eventCreationFailed(Error)
    case reminderCreationFailed(Error)
    case invalidDate
    case noDefaultCalendar
    
    var errorDescription: String? {
        switch self {
        case .calendarPermissionDenied:
            return "Calendar permission denied"
        case .reminderPermissionDenied:
            return "Reminders permission denied"
        case .eventCreationFailed(let error):
            return "Failed to create event: \(error.localizedDescription)"
        case .reminderCreationFailed(let error):
            return "Failed to create reminder: \(error.localizedDescription)"
        case .invalidDate:
            return "Invalid date format"
        case .noDefaultCalendar:
            return "No default calendar available"
        }
    }
}

// MARK: - EventKit Manager

@MainActor
class EventKitManager: ObservableObject {
    static let shared = EventKitManager()
    
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    
    private init() {
        checkAuthorizationStatuses()
    }
    
    // MARK: - Permission Management
    
    /// Check current authorization statuses
    func checkAuthorizationStatuses() {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    /// Request calendar permission
    func requestCalendarPermission() async throws -> Bool {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            checkAuthorizationStatuses()
            return granted
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        Task { @MainActor in
                            self.checkAuthorizationStatuses()
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    /// Request reminders permission
    func requestRemindersPermission() async throws -> Bool {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToReminders()
            checkAuthorizationStatuses()
            return granted
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        Task { @MainActor in
                            self.checkAuthorizationStatuses()
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    /// Check if calendar access is authorized
    func isCalendarAuthorized() -> Bool {
        if #available(iOS 17.0, *) {
            return calendarAuthorizationStatus == .fullAccess
        } else {
            return calendarAuthorizationStatus == .authorized
        }
    }
    
    /// Check if reminders access is authorized
    func isRemindersAuthorized() -> Bool {
        if #available(iOS 17.0, *) {
            return reminderAuthorizationStatus == .fullAccess
        } else {
            return reminderAuthorizationStatus == .authorized
        }
    }
    
    // MARK: - Calendar Event Creation
    
    /// Create a calendar event
    func createCalendarEvent(request: CalendarEventRequest) async throws -> CalendarEventResult {
        // Check permission
        if !isCalendarAuthorized() {
            // Try to request permission if not determined
            if calendarAuthorizationStatus == .notDetermined {
                let granted = try await requestCalendarPermission()
                if !granted {
                    return CalendarEventResult(eventID: nil, status: .deniedPermission)
                }
            } else {
                return CalendarEventResult(eventID: nil, status: .deniedPermission)
            }
        }
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: request.startISO),
              let endDate = formatter.date(from: request.endISO) else {
            throw EventKitError.invalidDate
        }
        
        // Get default calendar
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw EventKitError.noDefaultCalendar
        }
        
        // Create event
        let event = EKEvent(eventStore: eventStore)
        event.title = request.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        
        if let location = request.location {
            event.location = location
        }
        
        if let notes = request.notes {
            event.notes = notes
        }
        
        // Add alarms
        if let alarms = request.alarms {
            for alarm in alarms {
                let ekAlarm = EKAlarm(relativeOffset: -Double(alarm.leadMinutes * 60))
                event.addAlarm(ekAlarm)
            }
        }
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            return CalendarEventResult(eventID: event.eventIdentifier, status: .created)
        } catch {
            throw EventKitError.eventCreationFailed(error)
        }
    }
    
    // MARK: - Reminder Creation
    
    /// Create a reminder
    func createReminder(request: ReminderRequest) async throws -> ReminderResult {
        // Check permission
        if !isRemindersAuthorized() {
            // Try to request permission if not determined
            if reminderAuthorizationStatus == .notDetermined {
                let granted = try await requestRemindersPermission()
                if !granted {
                    return ReminderResult(reminderID: nil, status: .deniedPermission)
                }
            } else {
                return ReminderResult(reminderID: nil, status: .deniedPermission)
            }
        }
        
        // Get default calendar for reminders
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw EventKitError.noDefaultCalendar
        }
        
        // Create reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = request.title
        reminder.calendar = calendar
        
        if let notes = request.notes {
            reminder.notes = notes
        }
        
        // Set due date
        if let dueISO = request.dueISO {
            let formatter = ISO8601DateFormatter()
            guard let dueDate = formatter.date(from: dueISO) else {
                throw EventKitError.invalidDate
            }
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.dueDateComponents = components
        }
        
        // Set priority (0-9, where 0 is no priority)
        if let priority = request.priority {
            reminder.priority = priority
        }
        
        // Add alarms
        if let alarms = request.alarms {
            for alarm in alarms {
                let ekAlarm = EKAlarm(relativeOffset: -Double(alarm.leadMinutes * 60))
                reminder.addAlarm(ekAlarm)
            }
        }
        
        // Save reminder
        do {
            try eventStore.save(reminder, commit: true)
            return ReminderResult(reminderID: reminder.calendarItemIdentifier, status: .created)
        } catch {
            throw EventKitError.reminderCreationFailed(error)
        }
    }
    
    // MARK: - Event Management
    
    /// Fetch events in a date range
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard isCalendarAuthorized() else { return [] }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    /// Fetch incomplete reminders
    func fetchIncompleteReminders() async throws -> [EKReminder] {
        guard isRemindersAuthorized() else { return [] }
        
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    /// Delete an event
    func deleteEvent(eventIdentifier: String) throws {
        guard isCalendarAuthorized() else {
            throw EventKitError.calendarPermissionDenied
        }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return
        }
        
        try eventStore.remove(event, span: .thisEvent)
    }
    
    /// Delete a reminder
    func deleteReminder(reminderIdentifier: String) throws {
        guard isRemindersAuthorized() else {
            throw EventKitError.reminderPermissionDenied
        }
        
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            return
        }
        
        try eventStore.remove(reminder, commit: true)
    }
}
