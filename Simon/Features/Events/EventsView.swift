//
//  EventsView.swift
//  Simon
//
//  Redesigned for better UX and visual appeal
//

import SwiftUI

struct EventsView: View {
    @StateObject private var vm: EventsViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    init(vm: EventsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header with Stats
                    headerSection
                    
                    // Tab Selector
                    tabSelector
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                    
                    // Filter Bar (if coaches available)
                    if !vm.availableCoaches.isEmpty {
                        filterBar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                        
                        Divider()
                    }
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if vm.isLoading && vm.currentItems == 0 {
                                loadingView
                            } else if vm.isEmpty {
                                emptyStateView
                            } else {
                                contentView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                    .refreshable {
                        await vm.refresh()
                    }
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button {
                            vm.selectedCoachID = nil
                            vm.selectedStatus = nil
                            Task { await vm.refresh() }
                        } label: {
                            Label("Clear Filters", systemImage: "xmark.circle")
                        }
                        .disabled(vm.selectedCoachID == nil && vm.selectedStatus == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accentPrimary)
                    }
                }
            }
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
                if vm.showToast, let message = vm.toastMessage {
                    SToast(toast: ToastMessage(
                        type: vm.toastType,
                        message: message
                    ))
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.showToast)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                statCard(
                    icon: "calendar",
                    count: vm.calendarEvents.count,
                    label: "Events",
                    color: .blue
                )
                
                statCard(
                    icon: "checkmark.circle",
                    count: vm.reminders.count,
                    label: "Tasks",
                    color: .orange
                )
                
                statCard(
                    icon: "bell",
                    count: vm.notifications.count,
                    label: "Alerts",
                    color: .purple
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func statCard(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text("\(count)")
                    .font(theme.font(20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(theme.font(12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            
                            Text(tab.rawValue)
                                .font(theme.font(15, weight: .medium))
                        }
                        .foregroundColor(vm.selectedTab == tab ? theme.accentPrimary : .secondary)
                        
                        // Active indicator
                        Rectangle()
                            .fill(vm.selectedTab == tab ? theme.accentPrimary : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Coach Filter
            Menu {
                Button("All Coaches") {
                    vm.selectedCoachID = nil
                    Task { await vm.refresh() }
                }
                
                Divider()
                
                ForEach(vm.availableCoaches) { coach in
                    Button(coach.title) {
                        vm.selectedCoachID = coach.id
                        Task { await vm.refresh() }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 14))
                    
                    Text(vm.selectedCoachID == nil ? "All Coaches" : vm.availableCoaches.first(where: { $0.id == vm.selectedCoachID })?.title ?? "Coach")
                        .font(theme.font(13, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(vm.selectedCoachID == nil ? .secondary : theme.accentPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(vm.selectedCoachID == nil ? Color(.systemGray6) : theme.accentTint)
                .cornerRadius(8)
            }
            
            // Status Filter
            Menu {
                Button("All Status") {
                    vm.selectedStatus = nil
                    Task { await vm.refresh() }
                }
                
                Divider()
                
                ForEach(vm.selectedTab.statusOptions, id: \.self) { status in
                    Button(status.capitalized) {
                        vm.selectedStatus = status
                        Task { await vm.refresh() }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14))
                    
                    Text(vm.selectedStatus?.capitalized ?? "All Status")
                        .font(theme.font(13, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(vm.selectedStatus == nil ? .secondary : theme.accentPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(vm.selectedStatus == nil ? Color(.systemGray6) : theme.accentTint)
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch vm.selectedTab {
        case .calendar:
            calendarContent
        case .reminders:
            remindersContent
        case .notifications:
            notificationsContent
        }
    }
    
    private var calendarContent: some View {
        Group {
            if vm.calendarEvents.isEmpty {
                emptyStateView
            } else {
                ForEach(vm.calendarEvents) { event in
                    CalendarEventRow(event: event)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }
    
    private var remindersContent: some View {
        Group {
            if vm.reminders.isEmpty {
                emptyStateView
            } else {
                ForEach(vm.reminders) { reminder in
                    ReminderRow(
                        reminder: reminder,
                        onComplete: {
                            Task {
                                await vm.completeReminder(reminder.id)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }
    
    private var notificationsContent: some View {
        Group {
            if vm.notifications.isEmpty {
                emptyStateView
            } else {
                ForEach(vm.notifications) { notification in
                    NotificationRow(
                        notification: notification,
                        onCancel: {
                            Task {
                                await vm.cancelNotification(notification.id)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                loadingCard
            }
        }
        .padding(.top, 20)
    }
    
    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 12)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .redacted(reason: .placeholder)
        .shimmer()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: vm.selectedTab.emptyIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 60)
            
            VStack(spacing: 8) {
                Text(vm.selectedTab.emptyTitle)
                    .font(theme.font(20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(vm.selectedTab.emptyMessage)
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                // Navigate to chat or moment view
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create with Coach")
                }
                .font(theme.font(15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(theme.accentPrimary)
                .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Event Tab Extension

extension EventTab {
    var emptyIcon: String {
        switch self {
        case .calendar: return "calendar.badge.plus"
        case .reminders: return "checklist"
        case .notifications: return "bell.slash"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .calendar: return "No Events Yet"
        case .reminders: return "No Reminders"
        case .notifications: return "No Notifications"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .calendar: return "Ask your coach to schedule events and they'll appear here"
        case .reminders: return "Create reminders with your coach to stay on track"
        case .notifications: return "Set up notifications to get timely nudges"
        }
    }
    
    var statusOptions: [String] {
        switch self {
        case .calendar: return ["upcoming", "past"]
        case .reminders: return ["pending", "completed", "cancelled"]
        case .notifications: return ["scheduled", "delivered", "cancelled"]
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}
