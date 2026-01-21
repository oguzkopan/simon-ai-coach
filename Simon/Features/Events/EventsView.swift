//
//  EventsView.swift
//  Simon
//
//  Created for Event Persistence feature
//

import SwiftUI

struct EventsView: View {
    @StateObject private var vm: EventsViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    @State private var showCoachFilter = false
    @State private var showStatusFilter = false
    
    init(vm: EventsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                SSegmented(
                    options: EventTab.allCases,
                    displayName: { $0.rawValue },
                    selection: $vm.selectedTab
                )
                .padding(.horizontal, ThemeTokens.spacing16)
                .padding(.vertical, ThemeTokens.spacing12)
                .onChange(of: vm.selectedTab) { _, newTab in
                    Task {
                        await vm.selectTab(newTab)
                    }
                }
                
                // Filters
                if !vm.availableCoaches.isEmpty {
                    filterBar
                        .padding(.horizontal, ThemeTokens.spacing16)
                        .padding(.bottom, ThemeTokens.spacing12)
                }
                
                // Content
                ScrollView {
                    VStack(spacing: ThemeTokens.spacing16) {
                        if vm.isLoading && vm.currentItems == 0 {
                            // Loading state
                            loadingView
                        } else if vm.isEmpty {
                            // Empty state
                            emptyStateView
                        } else {
                            // Content
                            contentView
                        }
                    }
                    .padding(.horizontal, ThemeTokens.spacing16)
                    .padding(.bottom, 100) // Space for tab bar
                }
                .refreshable {
                    await vm.refresh()
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await vm.loadData()
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") {
                    vm.showError = false
                }
            } message: {
                if let error = vm.errorMessage {
                    Text(error)
                }
            }
            .overlay(alignment: .bottom) {
                // Toast notification
                if vm.showToast, let message = vm.toastMessage {
                    SToast(toast: ToastMessage(
                        type: vm.toastType,
                        message: message
                    ))
                    .padding(.bottom, 100) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.showToast)
                }
            }
            // Accessibility
            .accessibilityElement(children: .contain)
            .accessibilityLabel("My Schedule")
            .accessibilityHint("View and manage your calendar events, reminders, and notifications")
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack(spacing: ThemeTokens.spacing8) {
            // Coach filter
            Menu {
                Button("All Coaches") {
                    vm.selectedCoachID = nil
                    Task { await vm.applyFilters() }
                }
                
                Divider()
                
                ForEach(vm.availableCoaches) { coach in
                    Button(coach.title) {
                        vm.selectedCoachID = coach.id
                        Task { await vm.applyFilters() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCoachName)
                        .font(theme.font(14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(theme.accentPrimary)
                .padding(.horizontal, ThemeTokens.spacing12)
                .padding(.vertical, ThemeTokens.spacing8)
                .background(theme.accentTint)
                .cornerRadius(ThemeTokens.radiusSmall)
            }
            .accessibilityLabel("Filter by coach")
            .accessibilityHint("Currently showing: \(selectedCoachName)")
            .accessibilityAddTraits(.isButton)
            
            // Status filter
            Menu {
                Button("All") {
                    vm.selectedStatus = nil
                    Task { await vm.applyFilters() }
                }
                
                Divider()
                
                ForEach(statusOptions, id: \.self) { status in
                    Button(status.capitalized) {
                        vm.selectedStatus = status
                        Task { await vm.applyFilters() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedStatus?.capitalized ?? "All")
                        .font(theme.font(14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(theme.accentPrimary)
                .padding(.horizontal, ThemeTokens.spacing12)
                .padding(.vertical, ThemeTokens.spacing8)
                .background(theme.accentTint)
                .cornerRadius(ThemeTokens.radiusSmall)
            }
            .accessibilityLabel("Filter by status")
            .accessibilityHint("Currently showing: \(vm.selectedStatus?.capitalized ?? "All")")
            .accessibilityAddTraits(.isButton)
            
            Spacer()
            
            // Clear filters button
            if vm.hasFilters {
                Button(action: {
                    Task { await vm.clearFilters() }
                }) {
                    Text("Clear")
                        .font(theme.font(13, weight: .medium))
                        .foregroundColor(theme.accentPrimary)
                }
                .accessibilityLabel("Clear all filters")
                .accessibilityHint("Remove coach and status filters")
            }
        }
    }
    
    private var selectedCoachName: String {
        if let coachID = vm.selectedCoachID,
           let coach = vm.availableCoaches.first(where: { $0.id == coachID }) {
            return coach.title
        }
        return "All Coaches"
    }
    
    private var statusOptions: [String] {
        switch vm.selectedTab {
        case .calendar:
            return ["upcoming", "past"]
        case .reminders:
            return ["pending", "completed", "cancelled"]
        case .notifications:
            return ["scheduled", "delivered", "cancelled"]
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch vm.selectedTab {
        case .calendar:
            calendarEventsView
        case .reminders:
            remindersView
        case .notifications:
            notificationsView
        }
    }
    
    private var calendarEventsView: some View {
        LazyVStack(spacing: ThemeTokens.spacing12) {
            ForEach(vm.calendarEvents) { event in
                CalendarEventRow(event: event)
            }
            
            // Load more indicator
            if vm.isLoadingCalendar && vm.calendarEvents.count > 0 {
                ProgressView()
                    .padding()
            }
        }
        .onAppear {
            // Load more when reaching the end
            if !vm.isLoadingCalendar && vm.calendarEvents.count >= 50 {
                Task {
                    await vm.loadMore()
                }
            }
        }
    }
    
    private var remindersView: some View {
        LazyVStack(spacing: ThemeTokens.spacing12) {
            ForEach(vm.reminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    onComplete: {
                        Task {
                            await vm.completeReminder(id: reminder.id)
                        }
                    }
                )
            }
            
            // Load more indicator
            if vm.isLoadingReminders && vm.reminders.count > 0 {
                ProgressView()
                    .padding()
            }
        }
        .onAppear {
            // Load more when reaching the end
            if !vm.isLoadingReminders && vm.reminders.count >= 50 {
                Task {
                    await vm.loadMore()
                }
            }
        }
    }
    
    private var notificationsView: some View {
        LazyVStack(spacing: ThemeTokens.spacing12) {
            ForEach(vm.notifications) { notification in
                NotificationRow(
                    notification: notification,
                    onCancel: {
                        Task {
                            await vm.cancelNotification(id: notification.id)
                        }
                    }
                )
            }
            
            // Load more indicator
            if vm.isLoadingNotifications && vm.notifications.count > 0 {
                ProgressView()
                    .padding()
            }
        }
        .onAppear {
            // Load more when reaching the end
            if !vm.isLoadingNotifications && vm.notifications.count >= 50 {
                Task {
                    await vm.loadMore()
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: ThemeTokens.spacing16) {
            ForEach(0..<3, id: \.self) { _ in
                EventRowSkeleton()
            }
        }
        .padding(.top, ThemeTokens.spacing24)
    }
    
    // MARK: - Empty State View
    
    @ViewBuilder
    private var emptyStateView: some View {
        switch vm.selectedTab {
        case .calendar:
            SEmptyState(
                icon: "calendar",
                title: "No calendar events",
                message: vm.hasFilters
                    ? "No events match your filters. Try adjusting them."
                    : "Your coaches haven't created any calendar events yet. They'll appear here when they do."
            )
            .padding(.top, 60)
            
        case .reminders:
            SEmptyState(
                icon: "checklist",
                title: "No reminders",
                message: vm.hasFilters
                    ? "No reminders match your filters. Try adjusting them."
                    : "Your coaches haven't created any reminders yet. They'll appear here when they do."
            )
            .padding(.top, 60)
            
        case .notifications:
            SEmptyState(
                icon: "bell",
                title: "No notifications",
                message: vm.hasFilters
                    ? "No notifications match your filters. Try adjusting them."
                    : "Your coaches haven't scheduled any notifications yet. They'll appear here when they do."
            )
            .padding(.top, 60)
        }
    }
}

// MARK: - Event Row Skeleton

struct EventRowSkeleton: View {
    var body: some View {
        SCard {
            HStack(spacing: ThemeTokens.spacing12) {
                // Icon placeholder
                RoundedRectangle(cornerRadius: ThemeTokens.radiusSmall)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                
                // Content placeholder
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                        .frame(maxWidth: 200)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 14)
                        .frame(maxWidth: 150)
                }
                
                Spacer()
            }
            .padding(ThemeTokens.spacing12)
        }
    }
}

// MARK: - Preview

#Preview {
    EventsView(
        vm: EventsViewModel(
            apiClient: SimonAPIClient(baseURL: URL(string: "https://api.example.com")!)
        )
    )
    .environmentObject(ThemeStore())
}
