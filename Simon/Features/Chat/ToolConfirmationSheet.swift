import SwiftUI

struct ToolConfirmationSheet: View {
    let toolRequest: ToolRequestPayload
    let onApprove: () async -> Void
    let onDecline: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @State private var isExecuting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Tool Icon
                    Image(systemName: toolIcon)
                        .font(.system(size: 60))
                        .foregroundColor(theme.accentPrimary)
                        .padding(.top, 20)
                    
                    // Tool Title
                    Text(toolTitle)
                        .font(theme.font(22, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    // Tool Preview
                    toolPreview
                        .padding(.horizontal, 16)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Approve Button
                        Button(action: {
                            Task {
                                isExecuting = true
                                await onApprove()
                                isExecuting = false
                                dismiss()
                            }
                        }) {
                            HStack {
                                if isExecuting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Approve")
                                        .font(theme.font(17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(theme.accentPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isExecuting)
                        
                        // Decline Button
                        Button(action: {
                            onDecline()
                            dismiss()
                        }) {
                            Text("Decline")
                                .font(theme.font(17, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .disabled(isExecuting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Confirm Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDecline()
                        dismiss()
                    }
                    .disabled(isExecuting)
                }
            }
        }
    }
    
    // MARK: - Tool Icon Mapping
    
    private var toolIcon: String {
        switch toolRequest.toolId {
        case "local_notification_schedule":
            return "bell.fill"
        case "calendar_event_create":
            return "calendar.badge.plus"
        case "reminder_create":
            return "checklist"
        case "share_sheet_export":
            return "square.and.arrow.up"
        default:
            return "wrench.and.screwdriver"
        }
    }
    
    // MARK: - Tool Title Mapping
    
    private var toolTitle: String {
        switch toolRequest.toolId {
        case "local_notification_schedule":
            return "Schedule Notification"
        case "calendar_event_create":
            return "Create Calendar Event"
        case "reminder_create":
            return "Create Reminder"
        case "share_sheet_export":
            return "Export & Share"
        default:
            return "Confirm Tool Execution"
        }
    }
    
    // MARK: - Tool Preview
    
    @ViewBuilder
    private var toolPreview: some View {
        switch toolRequest.toolId {
        case "local_notification_schedule":
            NotificationPreview(input: toolRequest.input)
            
        case "calendar_event_create":
            CalendarEventPreview(input: toolRequest.input)
            
        case "reminder_create":
            ReminderPreview(input: toolRequest.input)
            
        case "share_sheet_export":
            ExportPreview(input: toolRequest.input)
            
        default:
            GenericToolPreview(input: toolRequest.input)
        }
    }
}

// MARK: - Preview Components

struct NotificationPreview: View {
    let input: [String: Any]
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let title = input["title"] as? String {
                        Text(title)
                            .font(theme.font(17, weight: .semibold))
                    }
                    
                    if let body = input["body"] as? String {
                        Text(body)
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    
                    if let trigger = input["trigger"] as? [String: Any],
                       let kind = trigger["kind"] as? String {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            
                            if kind == "at_datetime", let fireAt = trigger["fire_at_iso"] as? String {
                                Text("At: \(formatISO8601(fireAt))")
                                    .font(theme.font(13))
                            } else if kind == "after_delay", let delay = trigger["delay_sec"] as? Int {
                                Text("In \(delay / 60) minutes")
                                    .font(theme.font(13))
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct CalendarEventPreview: View {
    let input: [String: Any]
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewCard {
                VStack(alignment: .leading, spacing: 12) {
                    if let title = input["title"] as? String {
                        Text(title)
                            .font(theme.font(17, weight: .semibold))
                    }
                    
                    if let startISO = input["start_iso"] as? String,
                       let endISO = input["end_iso"] as? String {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text("\(formatISO8601(startISO)) - \(formatTime(endISO))")
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let location = input["location"] as? String, !location.isEmpty {
                        HStack {
                            Image(systemName: "location")
                                .font(.system(size: 14))
                            Text(location)
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let notes = input["notes"] as? String, !notes.isEmpty {
                        Text(notes)
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    if let alarms = input["alarms"] as? [[String: Any]], !alarms.isEmpty {
                        HStack {
                            Image(systemName: "bell")
                                .font(.system(size: 14))
                            Text("\(alarms.count) reminder(s)")
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ReminderPreview: View {
    let input: [String: Any]
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let title = input["title"] as? String {
                        Text(title)
                            .font(theme.font(17, weight: .semibold))
                    }
                    
                    if let notes = input["notes"] as? String, !notes.isEmpty {
                        Text(notes)
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                    
                    if let dueISO = input["due_iso"] as? String {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                            Text("Due: \(formatISO8601(dueISO))")
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let priority = input["priority"] as? Int, priority > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 14))
                            Text("Priority: \(priorityText(priority))")
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func priorityText(_ priority: Int) -> String {
        switch priority {
        case 1...3: return "High"
        case 4...6: return "Medium"
        default: return "Low"
        }
    }
}

struct ExportPreview: View {
    let input: [String: Any]
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let format = input["format"] as? String {
                        HStack {
                            Image(systemName: "doc")
                                .font(.system(size: 14))
                            Text("Format: \(format.uppercased())")
                                .font(theme.font(14, weight: .medium))
                        }
                    }
                    
                    if let payloadRef = input["payload_ref"] as? [String: Any],
                       let type = payloadRef["type"] as? String {
                        HStack {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                            Text("Content: \(type.capitalized)")
                                .font(theme.font(14))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Text("This will open the share sheet to export your content.")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct GenericToolPreview: View {
    let input: [String: Any]
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        PreviewCard {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(input.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(theme.font(13, weight: .medium))
                        Spacer()
                        Text(String(describing: input[key] ?? ""))
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct PreviewCard<Content: View>: View {
    let content: Content
    @EnvironmentObject private var theme: ThemeStore
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Helper Functions

private func formatISO8601(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: isoString) else {
        return isoString
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .short
    
    return displayFormatter.string(from: date)
}

private func formatTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: isoString) else {
        return isoString
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.timeStyle = .short
    
    return displayFormatter.string(from: date)
}
