//
//  MomentView.swift
//  Simon
//
//  Redesigned for better UX and visual appeal
//

import SwiftUI
import PhotosUI

struct MomentView: View {
    @StateObject private var vm: MomentViewModel
    @EnvironmentObject private var theme: ThemeStore
    @FocusState private var isTextFieldFocused: Bool
    
    init(vm: MomentViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        // Main Input Card
                        inputCard
                            .padding(.horizontal, 16)
                        
                        // Upcoming Events Section (always shown)
                        upcomingSection
                        
                        // Routines Section
                        if !vm.routines.isEmpty {
                            routinesSection
                        }
                        
                        // Divider
                        dividerSection
                            .padding(.horizontal, 16)
                        
                        // Quick Templates
                        templatesSection
                            .padding(.horizontal, 16)
                        
                        // Error message
                        if let errorMessage = vm.errorMessage {
                            errorCard(errorMessage)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
            .navigationTitle("Moment")
            .navigationBarTitleDisplayMode(.large)
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .sheet(item: $vm.selectedRoutine) { routine in
            SystemDetailView(system: routine)
        }
        .navigationDestination(isPresented: $vm.navigateToChat) {
            if let sessionId = vm.createdSessionId,
               let coachName = vm.createdCoachName {
                ChatView(viewModel: vm.createChatViewModel(
                    sessionId: sessionId,
                    coachName: coachName,
                    initialPrompt: vm.createdInitialPrompt
                ))
            }
        }
        .task {
            // Load all data in parallel on first appearance
            async let moments: Void = vm.loadRemainingMoments()
            async let routines: Void = vm.loadRoutines()
            async let events: Void = vm.loadUpcomingEvents()
            async let progress: Void = vm.loadProgressDocuments()
            
            _ = await (moments, routines, events, progress)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's on your mind?")
                .font(theme.font(28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Share what you're thinking, feeling, or working on")
                .font(theme.font(15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Input Card
    
    private var inputCard: some View {
        VStack(spacing: 0) {
            // Mode Toggle
            HStack(spacing: 0) {
                // Text Mode Button
                Button {
                    vm.toggleInputMode()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 14, weight: .medium))
                        Text("Text")
                            .font(theme.font(13, weight: .medium))
                    }
                    .foregroundColor(vm.inputMode == .text ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vm.inputMode == .text ? theme.accentPrimary : Color.clear)
                    .cornerRadius(8)
                }
                
                // Voice Mode Button
                Button {
                    vm.toggleInputMode()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .medium))
                        Text("Voice")
                            .font(theme.font(13, weight: .medium))
                    }
                    .foregroundColor(vm.inputMode == .voice ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vm.inputMode == .voice ? theme.accentPrimary : Color.clear)
                    .cornerRadius(8)
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .padding(.top, 12)
            
            // Input Area
            if vm.inputMode == .text {
                textInputArea
            } else {
                voiceInputArea
            }
            
            // Attached Files Preview
            if !vm.attachedFiles.isEmpty {
                Divider()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.attachedFiles) { file in
                            AttachmentPreview(file: file) {
                                vm.removeAttachment(file)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6).opacity(0.5))
            }
            
            Divider()
            
            // Bottom Action Bar
            bottomActionBar
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Text Input Area
    
    private var textInputArea: some View {
        ZStack(alignment: .topLeading) {
            if vm.freeformInput.isEmpty {
                Text("I'm feeling stuck on...\nI need help with...\nI want to talk about...")
                    .font(theme.font(15))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $vm.freeformInput)
                .font(theme.font(15))
                .frame(minHeight: 120)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .scrollContentBackground(.hidden)
                .focused($isTextFieldFocused)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Voice Input Area
    
    private var voiceInputArea: some View {
        VStack(spacing: 16) {
            if vm.isRecording {
                // Recording UI
                VStack(spacing: 20) {
                    // Waveform Visualization
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<vm.audioLevels.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.accentPrimary)
                                .frame(width: 3, height: max(4, vm.audioLevels[index] * 60))
                                .animation(.easeInOut(duration: 0.1), value: vm.audioLevels[index])
                        }
                    }
                    .frame(height: 60)
                    
                    // Recording Duration
                    Text(formatDuration(vm.recordingDuration))
                        .font(theme.font(24, weight: .semibold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    
                    Text("Recording...")
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                    
                    // Recording Controls
                    HStack(spacing: 24) {
                        // Cancel Button
                        Button {
                            vm.cancelVoiceRecording()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Cancel")
                                    .font(theme.font(12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Stop & Send Button
                        Button {
                            vm.stopVoiceRecording()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(theme.accentPrimary)
                                        .frame(width: 72, height: 72)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: theme.accentPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Text("Send")
                                    .font(theme.font(12, weight: .medium))
                                    .foregroundColor(theme.accentPrimary)
                            }
                        }
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            } else {
                // Ready to Record UI
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(theme.accentPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(theme.accentPrimary.opacity(0.2))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(theme.accentPrimary)
                    }
                    .padding(.top, 20)
                    
                    Text("Tap to start recording")
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                    
                    Button {
                        vm.startVoiceRecording()
                    } label: {
                        Text("Start Recording")
                            .font(theme.font(15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accentPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(minHeight: 120)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Attachment Button (available in both modes)
            PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            .onChange(of: vm.selectedPhotoItem) { _, _ in
                vm.handlePhotoSelection()
            }
            
            Spacer()
            
            // Character count (text mode only)
            if vm.inputMode == .text && !vm.freeformInput.isEmpty {
                Text("\(vm.freeformInput.count)")
                    .font(theme.font(12))
                    .foregroundColor(.secondary)
            }
            
            // Send Button (text mode only)
            if vm.inputMode == .text {
                Button(action: { 
                    isTextFieldFocused = false
                    vm.startFreeform()
                }) {
                    HStack(spacing: 6) {
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        (!vm.freeformInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isLoading) 
                            ? theme.accentPrimary 
                            : Color.secondary.opacity(0.3)
                    )
                    .clipShape(Circle())
                }
                .disabled(vm.freeformInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Upcoming Section
    
    private var hasUpcomingItems: Bool {
        !vm.upcomingEvents.isEmpty || !vm.pendingReminders.isEmpty || !vm.scheduledNotifications.isEmpty
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                
                Text("UPCOMING")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                let totalCount = vm.upcomingEvents.count + vm.pendingReminders.count + vm.scheduledNotifications.count
                
                if totalCount > 0 {
                    HStack(spacing: 8) {
                        Text("\(totalCount) items")
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                        
                        NavigationLink(destination: EventsView(vm: EventsViewModel(apiClient: vm.apiClient))) {
                            HStack(spacing: 4) {
                                Text("View All")
                                    .font(theme.font(13, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(theme.accentPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Show skeleton while loading (only on first load)
            if vm.isLoadingEvents {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            EventCardSkeleton()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            // Show empty state if no items
            else if !hasUpcomingItems {
                EmptyUpcomingState()
                    .padding(.horizontal, 16)
            }
            // Show actual items
            else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Calendar Events
                        ForEach(vm.upcomingEvents.prefix(5)) { event in
                            InteractiveEventCard(
                                icon: "calendar",
                                iconColor: .blue,
                                title: event.title,
                                subtitle: formatEventTime(event.startDate),
                                badge: "Event",
                                onTap: {
                                    vm.selectedEvent = event
                                    vm.showEventDetail = true
                                },
                                onDelete: {
                                    vm.deleteEvent(event)
                                }
                            )
                        }
                        
                        // Reminders
                        ForEach(vm.pendingReminders.prefix(5)) { reminder in
                            InteractiveEventCard(
                                icon: "checkmark.circle",
                                iconColor: .orange,
                                title: reminder.title,
                                subtitle: reminder.dueDate != nil ? formatEventTime(reminder.dueDate) : "No due date",
                                badge: "Task",
                                onTap: {
                                    vm.selectedReminder = reminder
                                    vm.showReminderDetail = true
                                },
                                onDelete: {
                                    vm.deleteReminder(reminder)
                                }
                            )
                        }
                        
                        // Notifications
                        ForEach(vm.scheduledNotifications.prefix(5)) { notification in
                            InteractiveEventCard(
                                icon: "bell",
                                iconColor: .purple,
                                title: notification.title,
                                subtitle: notification.triggerDescription,
                                badge: "Alert",
                                onTap: {
                                    vm.selectedNotification = notification
                                    vm.showNotificationDetail = true
                                },
                                onDelete: {
                                    vm.deleteNotification(notification)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $vm.showEventDetail) {
            if let event = vm.selectedEvent {
                EventDetailSheet(event: event, onDismiss: {
                    vm.showEventDetail = false
                    Task { await vm.loadUpcomingEvents() }
                })
            }
        }
        .sheet(isPresented: $vm.showReminderDetail) {
            if let reminder = vm.selectedReminder {
                ReminderDetailSheet(reminder: reminder, onDismiss: {
                    vm.showReminderDetail = false
                    Task { await vm.loadUpcomingEvents() }
                })
            }
        }
        .sheet(isPresented: $vm.showNotificationDetail) {
            if let notification = vm.selectedNotification {
                NotificationDetailSheet(notification: notification, onDismiss: {
                    vm.showNotificationDetail = false
                    Task { await vm.loadUpcomingEvents() }
                })
            }
        }
    }
    
    // MARK: - My Progress Section
    
    private var myProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                
                Text("MY PROGRESS")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            if vm.isLoadingProgress {
                // Skeleton loading - show all at once
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            ProgressCardSkeleton()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else if vm.activePlans.isEmpty && vm.recentCheckins.isEmpty {
                // Empty state
                EmptyProgressState()
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    // Active Plans
                    ForEach(vm.activePlans) { plan in
                        NavigationLink(destination: PlanView()) {
                            ProgressPlanCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Recent Check-ins (if any)
                    ForEach(vm.recentCheckins) { checkin in
                        ProgressCheckinCard(checkin: checkin)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Routines Section
    
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                
                Text("ROUTINES")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                if vm.pendingRoutinesCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text("\(vm.pendingRoutinesCount) Pending")
                            .font(theme.font(13))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                ForEach(vm.routines.prefix(3)) { routine in
                    RoutineCard(routine: routine) {
                        isTextFieldFocused = false
                        vm.openRoutine(routine)
                    }
                }
                
                if vm.routines.count > 3 {
                    Button {
                        // Navigate to full routines list
                    } label: {
                        HStack {
                            Text("View all \(vm.routines.count) routines")
                                .font(theme.font(14, weight: .medium))
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(theme.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.accentTint)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Divider Section
    
    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            
            Text("or choose a template")
                .font(theme.font(13))
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }
    
    // MARK: - Templates Section
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                
                Text("QUICK START")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(vm.templates) { template in
                    TemplateCard(
                        template: template,
                        isLoading: vm.isLoading && vm.selectedTemplate?.id == template.id
                    ) {
                        isTextFieldFocused = false
                        vm.startTemplate(template)
                    }
                }
            }
        }
    }
    
    // MARK: - Usage Card
    
    private var usageCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.accentTint)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.remainingMoments) moments left today")
                    .font(theme.font(15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Upgrade for unlimited access")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Upgrade") {
                vm.showPaywall = true
            }
            .font(theme.font(14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.accentPrimary)
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Error Card
    
    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)
            
            Text(message)
                .font(theme.font(14))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                vm.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func formatEventTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at " + formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at " + formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Interactive Event Card

struct InteractiveEventCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    
                    Spacer()
                    
                    // Delete button
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                Text(badge)
                    .font(theme.font(11, weight: .semibold))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(6)
                
                Text(title)
                    .font(theme.font(14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .top)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(subtitle)
                        .font(theme.font(12))
                }
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            .frame(width: 160)
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Delete Item", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
}

// MARK: - Routine Card

struct RoutineCard: View {
    let routine: System
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(needsAction ? Color.orange.opacity(0.1) : Color(.systemGray6))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(needsAction ? .orange : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title)
                        .font(theme.font(16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(statusText)
                        .font(theme.font(13))
                        .foregroundColor(needsAction ? .orange : .secondary)
                }
                
                Spacer()
                
                if needsAction {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var needsAction: Bool {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: routine.createdAt, to: Date()).day ?? 0
        return daysSinceCreation > 0
    }
    
    private var statusText: String {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: routine.createdAt, to: Date()).day ?? 0
        
        if daysSinceCreation == 0 {
            return "Last run: Today"
        } else if daysSinceCreation == 1 {
            return "Action Required"
        } else {
            return "Last run: \(daysSinceCreation)d ago"
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: MomentTemplate
    let isLoading: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.accentTint)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
                
                Text(template.title)
                    .font(theme.font(15, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .top)
                
                Text(template.description)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accentPrimary))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Attachment Preview

struct AttachmentPreview: View {
    let file: AttachedFile
    let onRemove: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if file.type == .image, let uiImage = UIImage(data: file.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .foregroundColor(.secondary)
                    )
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .offset(x: 6, y: -6)
        }
    }
}


// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: CalendarEventRecord
    let onDismiss: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Title
                    Text(event.title)
                        .font(theme.font(24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let startDate = event.startDate, let endDate = event.endDate {
                            DetailRow(
                                icon: "clock",
                                label: "Time",
                                value: formatDateRange(start: startDate, end: endDate)
                            )
                        }
                        
                        if let location = event.location {
                            DetailRow(
                                icon: "location",
                                label: "Location",
                                value: location
                            )
                        }
                        
                        if let notes = event.notes {
                            DetailRow(
                                icon: "note.text",
                                label: "Notes",
                                value: notes
                            )
                        }
                        
                        DetailRow(
                            icon: "circle.fill",
                            label: "Status",
                            value: event.statusDisplay
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        let startStr = formatter.string(from: start)
        formatter.dateFormat = "h:mm a"
        let endStr = formatter.string(from: end)
        return "\(startStr) - \(endStr)"
    }
}

// MARK: - Reminder Detail Sheet

struct ReminderDetailSheet: View {
    let reminder: ReminderRecord
    let onDismiss: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Title
                    Text(reminder.title)
                        .font(theme.font(24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let dueDate = reminder.dueDate {
                            DetailRow(
                                icon: "clock",
                                label: "Due Date",
                                value: formatDate(dueDate)
                            )
                        }
                        
                        DetailRow(
                            icon: "flag.fill",
                            label: "Priority",
                            value: reminder.priorityDisplay
                        )
                        
                        if let notes = reminder.notes {
                            DetailRow(
                                icon: "note.text",
                                label: "Notes",
                                value: notes
                            )
                        }
                        
                        DetailRow(
                            icon: "circle.fill",
                            label: "Status",
                            value: reminder.statusDisplay
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Detail Sheet

struct NotificationDetailSheet: View {
    let notification: ScheduledNotificationRecord
    let onDismiss: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Title
                    Text(notification.title)
                        .font(theme.font(24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(
                            icon: "text.bubble",
                            label: "Message",
                            value: notification.body
                        )
                        
                        DetailRow(
                            icon: "clock",
                            label: "Trigger",
                            value: notification.triggerDescription
                        )
                        
                        DetailRow(
                            icon: "circle.fill",
                            label: "Status",
                            value: notification.statusDisplay
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Notification Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(theme.font(13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(theme.font(15))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Event Card Skeleton

struct EventCardSkeleton: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                
                Spacer()
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 20, height: 20)
            }
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 16)
            }
            .frame(height: 40, alignment: .top)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 14)
        }
        .frame(width: 160)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty Upcoming State

struct EmptyUpcomingState: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("No upcoming items")
                .font(theme.font(14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(height: 40, alignment: .top)
            
            Text("Events and reminders will appear here")
                .font(theme.font(12))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(2)
        }
        .frame(width: 160)
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
    }
}


// MARK: - Progress Plan Card

struct ProgressPlanCard: View {
    let plan: Plan
    @EnvironmentObject private var theme: ThemeStore
    
    var completedMilestones: Int {
        plan.milestones.filter { $0.status == .completed }.count
    }
    
    var pendingActions: Int {
        plan.nextActions.filter { $0.status == .pending }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(completedMilestones)/\(plan.milestones.count) milestones • \(pendingActions) actions")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(completedMilestones) / CGFloat(max(plan.milestones.count, 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Progress Checkin Card

struct ProgressCheckinCard: View {
    let checkin: Checkin
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Check-in Schedule")
                    .font(theme.font(15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(checkin.cadence.kind.capitalized)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(checkin.status.capitalized)
                    .font(theme.font(12, weight: .medium))
                    .foregroundColor(checkin.status == "active" ? .green : .secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Progress Card Skeleton

struct ProgressCardSkeleton: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 14)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty Progress State

struct EmptyProgressState: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Text("No active plans or check-ins")
                .font(theme.font(14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Start a coaching session to create plans and track progress")
                .font(theme.font(12))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
    }
}
