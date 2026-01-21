import Foundation
import Combine
import UserNotifications

// MARK: - Notification Request Models

struct NotificationRequest: Codable {
    let title: String
    let body: String
    let trigger: NotificationTrigger
    let deepLink: DeepLink?
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case title, body, trigger
        case deepLink = "deep_link"
        case idempotencyKey = "idempotency_key"
    }
}

struct NotificationTrigger: Codable {
    let kind: TriggerKind
    let fireAtISO: String?
    let delaySec: Int?
    
    enum CodingKeys: String, CodingKey {
        case kind
        case fireAtISO = "fire_at_iso"
        case delaySec = "delay_sec"
    }
    
    enum TriggerKind: String, Codable {
        case atDatetime = "at_datetime"
        case afterDelay = "after_delay"
    }
}

struct DeepLink: Codable {
    let url: String
}

struct NotificationResult: Codable {
    let scheduledID: String
    let status: NotificationStatus
    
    enum CodingKeys: String, CodingKey {
        case scheduledID = "scheduled_id"
        case status
    }
    
    enum NotificationStatus: String, Codable {
        case scheduled
        case denied
        case failed
    }
}

// MARK: - Notification Manager

enum NotificationError: LocalizedError {
    case permissionDenied
    case invalidTrigger
    case schedulingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .invalidTrigger:
            return "Invalid notification trigger"
        case .schedulingFailed(let error):
            return "Failed to schedule notification: \(error.localizedDescription)"
        }
    }
}

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Management
    
    /// Request notification permission from the user
    func requestPermission() async throws -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            throw NotificationError.permissionDenied
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        await checkAuthorizationStatus()
        return authorizationStatus == .authorized
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule a notification based on the request
    func scheduleNotification(request: NotificationRequest) async throws -> NotificationResult {
        // Ensure permission (attempt to request if not determined)
        var authorized = await isAuthorized()
        if !authorized, authorizationStatus == .notDetermined {
            let granted = try await requestPermission()
            authorized = granted
        }
        
        // If still not authorized, return denied
        guard authorized else {
            return NotificationResult(
                scheduledID: request.idempotencyKey,
                status: .denied
            )
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        
        // Add deep link if provided
        if let deepLink = request.deepLink {
            content.userInfo = ["deepLink": deepLink.url]
        }
        
        // Create trigger
        let trigger: UNNotificationTrigger
        switch request.trigger.kind {
        case .atDatetime:
            guard let fireAtISO = request.trigger.fireAtISO,
                  let date = ISO8601DateFormatter().date(from: fireAtISO) else {
                throw NotificationError.invalidTrigger
            }
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
        case .afterDelay:
            guard let delaySec = request.trigger.delaySec, delaySec > 0 else {
                throw NotificationError.invalidTrigger
            }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delaySec), repeats: false)
        }
        
        // Create and add notification request
        let notificationRequest = UNNotificationRequest(
            identifier: request.idempotencyKey,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(notificationRequest)
            return NotificationResult(
                scheduledID: request.idempotencyKey,
                status: .scheduled
            )
        } catch {
            throw NotificationError.schedulingFailed(error)
        }
    }
    
    /// Schedule a repeating notification
    func scheduleRepeatingNotification(
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        weekdays: [Int]? = nil,
        identifier: String
    ) async throws {
        guard await isAuthorized() else {
            throw NotificationError.permissionDenied
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        if let weekdays = weekdays, !weekdays.isEmpty {
            // Schedule for specific weekdays
            for weekday in weekdays {
                dateComponents.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(identifier)_\(weekday)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }
        } else {
            // Schedule daily
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }
    
    // MARK: - Notification Management
    
    /// Cancel a scheduled notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    /// Get all pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
    
    /// Get delivered notifications
    func getDeliveredNotifications() async -> [UNNotification] {
        return await center.deliveredNotifications()
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep link from notification
    func handleDeepLink(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let urlString = userInfo["deepLink"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            // Handle deep link if present
            if let url = handleDeepLink(from: response.notification.request.content.userInfo) {
                // Post notification for deep link handling
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleDeepLink"),
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
        completionHandler()
    }
}
