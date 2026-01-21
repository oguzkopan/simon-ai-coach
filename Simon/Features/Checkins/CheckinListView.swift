import SwiftUI

struct CheckinListView: View {
    @StateObject private var viewModel = CheckinViewModel(apiClient: .shared)
    @State private var showingScheduleSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.checkins.isEmpty {
                    SFullScreenLoading()
                } else if viewModel.checkins.isEmpty {
                    emptyState
                } else {
                    checkinList
                }
            }
            .navigationTitle("Check-ins")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScheduleSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                ScheduleCheckinSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadCheckins()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        SEmptyState(
            icon: "bell.badge",
            title: "No Check-ins",
            message: "Schedule regular check-ins with your coaches to stay on track",
            primaryAction: EmptyStateAction(
                title: "Schedule Check-in",
                action: {
                    showingScheduleSheet = true
                }
            )
        )
    }
    
    // MARK: - Checkin List
    
    private var checkinList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.checkins) { checkin in
                    CheckinCard(checkin: checkin, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}

// MARK: - Checkin Card

struct CheckinCard: View {
    let checkin: Checkin
    @ObservedObject var viewModel: CheckinViewModel
    @State private var showingDeleteAlert = false
    
    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkin.cadence.displaySchedule)
                            .font(.headline)
                        
                        Text("Coach ID: \(checkin.coachId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    statusBadge
                }
                
                // Next run time
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Next: \(formatDate(checkin.nextRunAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Channel
                HStack {
                    Image(systemName: channelIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(channelName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.toggleCheckinStatus(
                                id: checkin.id,
                                currentStatus: checkin.status
                            )
                        }
                    } label: {
                        Label(
                            checkin.status == "active" ? "Pause" : "Resume",
                            systemImage: checkin.status == "active" ? "pause.circle" : "play.circle"
                        )
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
        .alert("Delete Check-in", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteCheckin(id: checkin.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this check-in?")
        }
    }
    
    private var statusBadge: some View {
        Text(checkin.status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch checkin.status {
        case "active": return .green
        case "paused": return .orange
        default: return .gray
        }
    }
    
    private var channelIcon: String {
        checkin.channel == "in_app" ? "app.badge" : "bell.badge"
    }
    
    private var channelName: String {
        checkin.channel == "in_app" ? "In-App" : "Notification"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Checkin Sheet

struct ScheduleCheckinSheet: View {
    @ObservedObject var viewModel: CheckinViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCoachId = ""
    @State private var selectedCadenceType = "daily"
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedChannel: CheckinChannel = .inApp
    
    let cadenceTypes = ["daily", "weekdays", "weekly"]
    let weekdayOptions = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Coach") {
                    TextField("Coach ID", text: $selectedCoachId)
                }
                
                Section("Schedule") {
                    Picker("Frequency", selection: $selectedCadenceType) {
                        Text("Daily").tag("daily")
                        Text("Weekdays").tag("weekdays")
                        Text("Weekly").tag("weekly")
                    }
                    
                    if selectedCadenceType == "weekly" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(weekdayOptions, id: \.0) { day, name in
                                    Button {
                                        if selectedWeekdays.contains(day) {
                                            selectedWeekdays.remove(day)
                                        } else {
                                            selectedWeekdays.insert(day)
                                        }
                                    } label: {
                                        Text(name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                selectedWeekdays.contains(day) ?
                                                Color.accentColor : Color.gray.opacity(0.2)
                                            )
                                            .foregroundColor(
                                                selectedWeekdays.contains(day) ?
                                                .white : .primary
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        
                        Text(":")
                        
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                    }
                }
                
                Section("Delivery") {
                    Picker("Channel", selection: $selectedChannel) {
                        ForEach(CheckinChannel.allCases, id: \.self) { channel in
                            Text(channel.displayName).tag(channel)
                        }
                    }
                }
            }
            .navigationTitle("Schedule Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        Task {
                            let cadence: CheckinCadence
                            
                            switch selectedCadenceType {
                            case "daily":
                                cadence = .daily(hour: selectedHour, minute: selectedMinute)
                            case "weekdays":
                                cadence = .weekdays(hour: selectedHour, minute: selectedMinute)
                            case "weekly":
                                cadence = .weekly(
                                    hour: selectedHour,
                                    minute: selectedMinute,
                                    weekdays: Array(selectedWeekdays).sorted()
                                )
                            default:
                                cadence = .daily(hour: selectedHour, minute: selectedMinute)
                            }
                            
                            let success = await viewModel.scheduleCheckin(
                                coachId: selectedCoachId,
                                cadence: cadence,
                                channel: selectedChannel
                            )
                            
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedCoachId.isEmpty || (selectedCadenceType == "weekly" && selectedWeekdays.isEmpty))
                }
            }
        }
    }
}
