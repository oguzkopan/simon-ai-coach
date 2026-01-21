//
//  ReminderRow.swift
//  Simon
//
//  Created for Event Persistence feature
//

import SwiftUI

struct ReminderRow: View {
    let reminder: ReminderRecord
    let onComplete: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @State private var showingCompletionConfirmation = false
    
    var body: some View {
        SCard {
            HStack(spacing: ThemeTokens.spacing12) {
                // Completion checkbox
                Button(action: {
                    if !reminder.isCompleted {
                        showingCompletionConfirmation = true
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeTokens.radiusSmall)
                            .fill(checkboxColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(checkboxColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(reminder.isCompleted)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(reminder.title)
                        .font(theme.font(16, weight: .semibold))
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                        .strikethrough(reminder.isCompleted)
                        .lineLimit(2)
                    
                    // Due date
                    if let dueDate = reminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(formattedDueDate(dueDate))
                                .font(theme.font(13))
                        }
                        .foregroundColor(dueDateColor)
                    }
                    
                    // Priority
                    if reminder.priority > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                            Text(reminder.priorityDisplay)
                                .font(theme.font(13))
                        }
                        .foregroundColor(priorityColor)
                    }
                    
                    // Coach name
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("Coach")
                            .font(theme.font(13))
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                if reminder.isCompleted {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        if let completedAt = reminder.completedAt {
                            Text(completedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(theme.font(10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(ThemeTokens.spacing12)
            .opacity(reminder.isCompleted ? 0.6 : 1.0)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !reminder.isCompleted {
                Button(action: {
                    showingCompletionConfirmation = true
                }) {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(.green)
                .accessibilityLabel("Mark reminder as complete")
            }
        }
        .confirmationDialog(
            "Complete Reminder",
            isPresented: $showingCompletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mark as Complete") {
                onComplete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark '\(reminder.title)' as complete?")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(reminder.isCompleted ? [] : .isButton)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var label = reminder.title
        
        if let dueDate = reminder.dueDate {
            label += ", \(formattedDueDate(dueDate))"
        }
        
        if reminder.priority > 0 {
            label += ", \(reminder.priorityDisplay) priority"
        }
        
        if reminder.isCompleted {
            label += ", completed"
            if let completedAt = reminder.completedAt {
                label += " on \(completedAt.formatted(date: .abbreviated, time: .omitted))"
            }
        }
        
        return label
    }
    
    private var accessibilityHint: String {
        if reminder.isCompleted {
            return "This reminder has been completed"
        } else {
            return "Double tap to mark as complete"
        }
    }
    
    // MARK: - Computed Properties
    
    private var checkboxColor: Color {
        if reminder.isCompleted {
            return .green
        } else if reminder.isOverdue {
            return .red
        } else {
            return theme.accentPrimary
        }
    }
    
    private var dueDateColor: Color {
        if reminder.isCompleted {
            return .secondary
        } else if reminder.isOverdue {
            return .red
        } else {
            return .secondary
        }
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case 7...9:
            return .red
        case 4...6:
            return .orange
        default:
            return .secondary
        }
    }
    
    private func formattedDueDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        // Check if overdue
        if date < now && !reminder.isCompleted {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day {
                if days == 0 {
                    return "Overdue (today)"
                } else if days == 1 {
                    return "Overdue (1 day)"
                } else {
                    return "Overdue (\(days) days)"
                }
            }
        }
        
        // Check if it's today
        if calendar.isDateInToday(date) {
            return "Due today at \(formatTime(date))"
        }
        
        // Check if it's tomorrow
        if calendar.isDateInTomorrow(date) {
            return "Due tomorrow at \(formatTime(date))"
        }
        
        // Check if it's within this week
        if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now),
           date < weekFromNow {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            return "Due \(weekday) at \(formatTime(date))"
        }
        
        // Otherwise show full date
        return "Due \(date.formatted(date: .abbreviated, time: .shortened))"
    }
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
