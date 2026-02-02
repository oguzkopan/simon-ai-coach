//
//  ReminderRow.swift
//  Simon
//
//  Redesigned reminder row
//

import SwiftUI

struct ReminderRow: View {
    let reminder: ReminderRecord
    let onComplete: () -> Void
    @EnvironmentObject private var theme: ThemeStore
    @State private var isCompleting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button {
                if !reminder.isCompleted {
                    isCompleting = true
                    onComplete()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(checkboxColor, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(checkboxColor)
                    }
                    
                    if isCompleting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .disabled(reminder.isCompleted || isCompleting)
            
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                    .strikethrough(reminder.isCompleted)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Due Date
                    if let dueDate = reminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: reminder.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                                .font(.system(size: 12))
                            Text(formatDueDate(dueDate))
                                .font(theme.font(13))
                        }
                        .foregroundColor(reminder.isOverdue ? .red : .secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text("No due date")
                                .font(theme.font(13))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Priority
                    if reminder.priority > 0 {
                        priorityBadge
                    }
                }
                
                // Notes preview
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(reminder.isCompleted ? 0.6 : 1.0)
    }
    
    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 10))
            Text(reminder.priorityDisplay)
                .font(theme.font(11, weight: .medium))
        }
        .foregroundColor(priorityColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(priorityColor.opacity(0.1))
        .cornerRadius(4)
    }
    
    private var checkboxColor: Color {
        if reminder.isCompleted {
            return .green
        } else if reminder.isOverdue {
            return .red
        } else {
            return .orange
        }
    }
    
    private var iconColor: Color {
        if reminder.isCompleted {
            return .green
        } else if reminder.isOverdue {
            return .red
        } else {
            return .orange
        }
    }
    
    private var iconBackgroundColor: Color {
        if reminder.isCompleted {
            return Color.green.opacity(0.1)
        } else if reminder.isOverdue {
            return Color.red.opacity(0.1)
        } else {
            return Color.orange.opacity(0.1)
        }
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case 7...9: return .red
        case 4...6: return .orange
        default: return .blue
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Overdue"
        } else if date < Date() {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "Overdue by \(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due " + formatter.string(from: date)
        }
    }
}
