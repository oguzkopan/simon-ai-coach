import Foundation

// MARK: - Checkin
struct Checkin: Identifiable, Codable, Equatable {
    let id: String
    let uid: String
    let coachId: String
    let cadence: CheckinCadence
    let channel: String // "in_app" | "local_notification_proposal"
    let nextRunAt: Date
    let lastRunAt: Date?
    let status: String // "active" | "paused" | "deleted"
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case coachId = "coach_id"
        case cadence
        case channel
        case nextRunAt = "next_run_at"
        case lastRunAt = "last_run_at"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CheckinCadence
struct CheckinCadence: Codable, Equatable {
    let kind: String // "daily" | "weekdays" | "weekly" | "custom_cron"
    let hour: Int
    let minute: Int
    let weekdays: [Int]? // 1=Sun, 2=Mon, ..., 7=Sat
    let cron: String?
    
    enum CodingKeys: String, CodingKey {
        case kind
        case hour
        case minute
        case weekdays
        case cron
    }
    
    // MARK: - Convenience Initializers
    
    /// Creates a daily check-in cadence
    static func daily(hour: Int, minute: Int) -> CheckinCadence {
        CheckinCadence(kind: "daily", hour: hour, minute: minute, weekdays: nil, cron: nil)
    }
    
    /// Creates a weekdays (Mon-Fri) check-in cadence
    static func weekdays(hour: Int, minute: Int) -> CheckinCadence {
        CheckinCadence(kind: "weekdays", hour: hour, minute: minute, weekdays: nil, cron: nil)
    }
    
    /// Creates a weekly check-in cadence for specific days
    /// - Parameter weekdays: Array of weekday numbers (1=Sun, 2=Mon, ..., 7=Sat)
    static func weekly(hour: Int, minute: Int, weekdays: [Int]) -> CheckinCadence {
        CheckinCadence(kind: "weekly", hour: hour, minute: minute, weekdays: weekdays, cron: nil)
    }
    
    /// Creates a custom cron-based check-in cadence
    static func custom(cron: String) -> CheckinCadence {
        CheckinCadence(kind: "custom_cron", hour: 0, minute: 0, weekdays: nil, cron: cron)
    }
    
    // MARK: - Display Helpers
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    var displaySchedule: String {
        switch kind {
        case "daily":
            return "Every day at \(displayTime)"
        case "weekdays":
            return "Weekdays at \(displayTime)"
        case "weekly":
            if let weekdays = weekdays, !weekdays.isEmpty {
                let dayNames = weekdays.sorted().map { weekdayName(for: $0) }
                return "\(dayNames.joined(separator: ", ")) at \(displayTime)"
            }
            return "Weekly at \(displayTime)"
        case "custom_cron":
            return cron ?? "Custom schedule"
        default:
            return "Unknown schedule"
        }
    }
    
    private func weekdayName(for day: Int) -> String {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }
}

// MARK: - CheckinChannel
enum CheckinChannel: String, CaseIterable {
    case inApp = "in_app"
    case localNotification = "local_notification_proposal"
    
    var displayName: String {
        switch self {
        case .inApp:
            return "In-App"
        case .localNotification:
            return "Notification"
        }
    }
}
