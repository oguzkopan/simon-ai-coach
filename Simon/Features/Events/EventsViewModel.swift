//
//  EventsViewModel.swift
//  Simon
//
//  Created for Event Persistence feature
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class EventsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Tab selection
    @Published var selectedTab: EventTab = .calendar
    
    // Data
    @Published var calendarEvents: [CalendarEventRecord] = []
    @Published var reminders: [ReminderRecord] = []
    @Published var notifications: [ScheduledNotificationRecord] = []
    
    // Filters
    @Published var selectedCoachID: String? = nil
    @Published var selectedStatus: String? = nil
    @Published var availableCoaches: [Coach] = []
    
    // Loading states
    @Published var isLoadingCalendar = false
    @Published var isLoadingReminders = false
    @Published var isLoadingNotifications = false
    @Published var isLoadingCoaches = false
    
    // Error states
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Toast notifications
    @Published var toastMessage: String?
    @Published var toastType: ToastType = .success
    @Published var showToast = false
    
    // Pagination
    private var calendarOffset = 0
    private var remindersOffset = 0
    private var notificationsOffset = 0
    private let pageSize = 50
    
    // Cache
    private var eventCache: [String: [Any]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    // Debounce
    private var filterDebounceTask: Task<Void, Never>?
    private var loadCalendarTask: Task<Void, Never>?
    private var loadRemindersTask: Task<Void, Never>?
    private var loadNotificationsTask: Task<Void, Never>?
    private var loadCoachesTask: Task<Void, Never>?
    
    // MARK: - Dependencies
    
    private let apiClient: SimonAPI
    private let persistenceService: EventPersistenceService
    private let authManager: AuthenticationManager
    
    // MARK: - Initialization
    
    init(
        apiClient: SimonAPI,
        persistenceService: EventPersistenceService = .shared,
        authManager: AuthenticationManager = .shared,
        initialCoachFilter: String? = nil
    ) {
        self.apiClient = apiClient
        self.persistenceService = persistenceService
        self.authManager = authManager
        self.selectedCoachID = initialCoachFilter
    }
    
    deinit {
        // Cancel all ongoing tasks when view model is deallocated
        loadCalendarTask?.cancel()
        loadRemindersTask?.cancel()
        loadNotificationsTask?.cancel()
        loadCoachesTask?.cancel()
        filterDebounceTask?.cancel()
    }
    
    // MARK: - Data Loading
    
    /// Load all data for all tabs at once
    func loadData() async {
        await loadCoaches()
        
        // Load all data in parallel
        async let calendarTask: Void = loadCalendarEvents()
        async let remindersTask: Void = loadReminders()
        async let notificationsTask: Void = loadScheduledNotifications()
        
        // Wait for all to complete
        _ = await (calendarTask, remindersTask, notificationsTask)
    }
    
    /// Refresh all data (for pull-to-refresh)
    func refresh() async {
        // Reset pagination
        calendarOffset = 0
        remindersOffset = 0
        notificationsOffset = 0
        
        // Clear existing data
        calendarEvents = []
        reminders = []
        notifications = []
        
        // Reload all data
        await loadData()
    }
    
    /// Load calendar events with filtering
    func loadCalendarEvents() async {
        // Cancel any existing task
        loadCalendarTask?.cancel()
        
        guard !isLoadingCalendar else { return }
        guard let uid = authManager.currentUser?.uid else {
            print("⚠️ No user ID available for loading calendar events")
            return
        }
        
        isLoadingCalendar = true
        errorMessage = nil
        
        loadCalendarTask = Task {
            do {
                // Debug logging
                print("🔍 Loading calendar events...")
                print("🔍 UID: \(uid)")
                print("🔍 Coach filter: \(selectedCoachID ?? "none")")
                print("🔍 Status filter: \(selectedStatus ?? "none")")
                
                // Use EventPersistenceService directly (same as MomentView)
                let events = try await persistenceService.listCalendarEvents(
                    uid: uid,
                    coachID: selectedCoachID,
                    status: selectedStatus,
                    limit: pageSize
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                print("✅ Loaded \(events.count) calendar events from Firestore")
                if events.isEmpty {
                    print("⚠️ No calendar events found in Firestore")
                } else {
                    print("📋 First event: \(events[0].title)")
                }
                
                if calendarOffset == 0 {
                    calendarEvents = events
                } else {
                    calendarEvents.append(contentsOf: events)
                }
                
                calendarOffset += events.count
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ Failed to load calendar events: \(error)")
                handleError(error, context: "loading calendar events")
            }
            
            isLoadingCalendar = false
        }
        
        await loadCalendarTask?.value
    }
    
    /// Load reminders with filtering
    func loadReminders() async {
        // Cancel any existing task
        loadRemindersTask?.cancel()
        
        guard !isLoadingReminders else { return }
        guard let uid = authManager.currentUser?.uid else {
            print("⚠️ No user ID available for loading reminders")
            return
        }
        
        isLoadingReminders = true
        errorMessage = nil
        
        loadRemindersTask = Task {
            do {
                print("🔍 Loading reminders for UID: \(uid)")
                
                // Use EventPersistenceService directly
                let items = try await persistenceService.listReminders(
                    uid: uid,
                    coachID: selectedCoachID,
                    status: selectedStatus ?? "pending",
                    limit: pageSize
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                print("✅ Loaded \(items.count) reminders from Firestore")
                
                if remindersOffset == 0 {
                    reminders = items
                } else {
                    reminders.append(contentsOf: items)
                }
                
                remindersOffset += items.count
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ Failed to load reminders: \(error)")
                handleError(error, context: "loading reminders")
            }
            
            isLoadingReminders = false
        }
        
        await loadRemindersTask?.value
    }
    
    /// Load scheduled notifications with filtering
    func loadScheduledNotifications() async {
        // Cancel any existing task
        loadNotificationsTask?.cancel()
        
        guard !isLoadingNotifications else { return }
        guard let uid = authManager.currentUser?.uid else {
            print("⚠️ No user ID available for loading notifications")
            return
        }
        
        isLoadingNotifications = true
        errorMessage = nil
        
        loadNotificationsTask = Task {
            do {
                print("🔍 Loading notifications for UID: \(uid)")
                
                // Use EventPersistenceService directly
                let items = try await persistenceService.listScheduledNotifications(
                    uid: uid,
                    coachID: selectedCoachID,
                    status: selectedStatus ?? "scheduled",
                    limit: pageSize
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                print("✅ Loaded \(items.count) notifications from Firestore")
                
                if notificationsOffset == 0 {
                    notifications = items
                } else {
                    notifications.append(contentsOf: items)
                }
                
                notificationsOffset += items.count
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ Failed to load notifications: \(error)")
                handleError(error, context: "loading notifications")
            }
            
            isLoadingNotifications = false
        }
        
        await loadNotificationsTask?.value
    }
    
    /// Load available coaches for filtering
    func loadCoaches() async {
        // Cancel any existing task
        loadCoachesTask?.cancel()
        
        guard !isLoadingCoaches else { return }
        
        isLoadingCoaches = true
        
        loadCoachesTask = Task {
            do {
                let coaches = try await apiClient.listCoaches(tag: nil, featured: nil)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                availableCoaches = coaches
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load coaches: \(error)")
                // Don't show error for coaches - it's not critical
            }
            
            isLoadingCoaches = false
        }
        
        await loadCoachesTask?.value
    }
    
    // MARK: - Actions
    
    /// Complete a reminder with optimistic update and haptic feedback
    func completeReminder(id: String) async {
        // Find the reminder
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        let originalReminder = reminders[index]
        
        // Haptic feedback
        HapticManager.shared.light()
        
        // Optimistic update with animation
        _ = withAnimation(.easeInOut(duration: 0.3)) {
            reminders.remove(at: index)
        }
        
        do {
            // Call API to complete
            let completedReminder = try await apiClient.completeReminder(id: id)
            
            // Success haptic and toast
            HapticManager.shared.success()
            showToastMessage("Reminder completed", type: .success)
            
            // Update with server response
            if selectedStatus == nil || selectedStatus == "completed" {
                withAnimation(.easeInOut(duration: 0.3)) {
                    reminders.insert(completedReminder, at: 0)
                }
            }
            
            // Invalidate cache
            invalidateCache()
            
        } catch {
            // Rollback on error with animation
            HapticManager.shared.error()
            withAnimation(.easeInOut(duration: 0.3)) {
                reminders.insert(originalReminder, at: index)
            }
            handleError(error, context: "completing reminder")
        }
    }
    
    /// Cancel a notification with optimistic update and haptic feedback
    func cancelNotification(id: String) async {
        // Find the notification
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        let originalNotification = notifications[index]
        
        // Haptic feedback
        HapticManager.shared.light()
        
        // Optimistic update with animation
        _ = withAnimation(.easeInOut(duration: 0.3)) {
            notifications.remove(at: index)
        }
        
        do {
            // Call API to cancel
            let cancelledNotification = try await apiClient.cancelNotification(id: id)
            
            // Success haptic and toast
            HapticManager.shared.success()
            showToastMessage("Notification cancelled", type: .success)
            
            // Update with server response
            if selectedStatus == nil || selectedStatus == "cancelled" {
                withAnimation(.easeInOut(duration: 0.3)) {
                    notifications.insert(cancelledNotification, at: 0)
                }
            }
            
            // Invalidate cache
            invalidateCache()
            
        } catch {
            // Rollback on error with animation
            HapticManager.shared.error()
            withAnimation(.easeInOut(duration: 0.3)) {
                notifications.insert(originalNotification, at: index)
            }
            handleError(error, context: "cancelling notification")
        }
    }
    
    // MARK: - Filtering
    
    /// Apply filter and reload data with debouncing
    func applyFilters() async {
        // Cancel previous debounce task
        filterDebounceTask?.cancel()
        
        // Create new debounced task
        filterDebounceTask = Task {
            // Wait for debounce period
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            // Reset pagination
            calendarOffset = 0
            remindersOffset = 0
            notificationsOffset = 0
            
            // Clear existing data
            calendarEvents = []
            reminders = []
            notifications = []
            
            // Invalidate cache
            invalidateCache()
            
            // Reload with new filters
            await loadData()
        }
        
        await filterDebounceTask?.value
    }
    
    /// Clear all filters
    func clearFilters() async {
        selectedCoachID = nil
        selectedStatus = nil
        await applyFilters()
    }
    
    // MARK: - Cache Management
    
    /// Check if cache is valid for a given key
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamps[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheTTL
    }
    
    /// Invalidate all caches
    private func invalidateCache() {
        eventCache.removeAll()
        cacheTimestamps.removeAll()
    }
    
    // MARK: - Toast Notifications
    
    /// Show a toast message
    private func showToastMessage(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        showToast = true
        
        // Auto-dismiss after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showToast = false
        }
    }
    
    // MARK: - Pagination
    
    /// Load more items for the current tab
    func loadMore() async {
        switch selectedTab {
        case .calendar:
            await loadCalendarEvents()
        case .reminders:
            await loadReminders()
        case .notifications:
            await loadScheduledNotifications()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: String) {
        print("Error \(context): \(error)")
        
        // Convert error to user-friendly message
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse:
                errorMessage = "Unable to connect to server. Please try again."
            case .httpError(let code):
                if code == 401 {
                    errorMessage = "Please sign in to view your events."
                } else if code == 403 {
                    errorMessage = "You don't have permission to access these events."
                } else if code >= 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = "Failed to \(context). Please try again."
                }
            case .decodingError:
                errorMessage = "Unable to process server response."
            case .proRequired:
                errorMessage = "Pro subscription required for this feature."
            }
        } else {
            errorMessage = "Failed to \(context). Please check your connection and try again."
        }
        
        showError = true
    }
    
    // MARK: - Actions
    
    /// Complete a reminder
    func completeReminder(_ reminderID: String) async {
        guard let uid = authManager.currentUser?.uid else { return }
        
        do {
            // Use EventPersistenceService directly
            try await persistenceService.completeReminder(id: reminderID, uid: uid)
            
            // Update local state - remove from list or update status
            if let index = reminders.firstIndex(where: { $0.id == reminderID }) {
                reminders.remove(at: index)
            }
            
            showToastMessage("Reminder completed", type: .success)
        } catch {
            handleError(error, context: "completing reminder")
        }
    }
    
    /// Cancel a notification
    func cancelNotification(_ notificationID: String) async {
        guard let uid = authManager.currentUser?.uid else { return }
        
        do {
            // Use EventPersistenceService directly
            try await persistenceService.cancelNotification(id: notificationID, uid: uid)
            
            // Update local state - remove from list
            if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
                notifications.remove(at: index)
            }
            
            showToastMessage("Notification cancelled", type: .success)
        } catch {
            handleError(error, context: "cancelling notification")
        }
    }
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        isLoadingCalendar || isLoadingReminders || isLoadingNotifications
    }
    
    var hasFilters: Bool {
        selectedCoachID != nil || selectedStatus != nil
    }
    
    var currentItems: Int {
        switch selectedTab {
        case .calendar:
            return calendarEvents.count
        case .reminders:
            return reminders.count
        case .notifications:
            return notifications.count
        }
    }
    
    var isEmpty: Bool {
        currentItems == 0 && !isLoading
    }
}

// MARK: - Event Tab Enum

enum EventTab: String, CaseIterable, Hashable {
    case calendar = "Calendar"
    case reminders = "Reminders"
    case notifications = "Notifications"
    
    var icon: String {
        switch self {
        case .calendar:
            return "calendar"
        case .reminders:
            return "checkmark.circle"
        case .notifications:
            return "bell"
        }
    }
}
