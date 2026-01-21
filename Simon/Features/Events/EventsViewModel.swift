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
    
    /// Load all data for the current tab
    func loadData() async {
        await loadCoaches()
        
        switch selectedTab {
        case .calendar:
            await loadCalendarEvents()
        case .reminders:
            await loadReminders()
        case .notifications:
            await loadScheduledNotifications()
        }
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
        
        // Reload
        await loadData()
    }
    
    /// Load calendar events with filtering
    func loadCalendarEvents() async {
        // Cancel any existing task
        loadCalendarTask?.cancel()
        
        guard !isLoadingCalendar else { return }
        
        isLoadingCalendar = true
        errorMessage = nil
        
        loadCalendarTask = Task {
            do {
                let events = try await apiClient.getCalendarEvents(
                    coachID: selectedCoachID,
                    status: selectedStatus,
                    limit: pageSize,
                    offset: calendarOffset
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                if calendarOffset == 0 {
                    calendarEvents = events
                } else {
                    calendarEvents.append(contentsOf: events)
                }
                
                calendarOffset += events.count
            } catch {
                guard !Task.isCancelled else { return }
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
        
        isLoadingReminders = true
        errorMessage = nil
        
        loadRemindersTask = Task {
            do {
                let items = try await apiClient.getReminders(
                    coachID: selectedCoachID,
                    status: selectedStatus,
                    limit: pageSize,
                    offset: remindersOffset
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                if remindersOffset == 0 {
                    reminders = items
                } else {
                    reminders.append(contentsOf: items)
                }
                
                remindersOffset += items.count
            } catch {
                guard !Task.isCancelled else { return }
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
        
        isLoadingNotifications = true
        errorMessage = nil
        
        loadNotificationsTask = Task {
            do {
                let items = try await apiClient.getScheduledNotifications(
                    coachID: selectedCoachID,
                    status: selectedStatus,
                    limit: pageSize,
                    offset: notificationsOffset
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                if notificationsOffset == 0 {
                    notifications = items
                } else {
                    notifications.append(contentsOf: items)
                }
                
                notificationsOffset += items.count
            } catch {
                guard !Task.isCancelled else { return }
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
    
    // MARK: - Tab Selection
    
    /// Switch to a different tab
    func selectTab(_ tab: EventTab) async {
        selectedTab = tab
        
        // Load data for the new tab if not already loaded
        switch tab {
        case .calendar where calendarEvents.isEmpty:
            await loadCalendarEvents()
        case .reminders where reminders.isEmpty:
            await loadReminders()
        case .notifications where notifications.isEmpty:
            await loadScheduledNotifications()
        default:
            break
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
}

