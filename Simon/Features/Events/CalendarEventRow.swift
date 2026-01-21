//
//  CalendarEventRow.swift
//  Simon
//
//  Created for Event Persistence feature
//

import SwiftUI
import Combine

struct CalendarEventRow: View {
    let event: CalendarEventRecord
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button(action: openInCalendar) {
            SCard {
                HStack(spacing: ThemeTokens.spacing12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeTokens.radiusSmall)
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(event.title)
                            .font(theme.font(16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        // Date/Time
                        Text(formattedDateTime)
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                        
                        // Location (if available)
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(location)
                                    .font(theme.font(13))
                            }
                            .foregroundColor(.secondary)
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
                    VStack(spacing: 8) {
                        statusBadge
                        
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(ThemeTokens.spacing12)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        event.isPast ? Color.gray : theme.accentPrimary
    }
    
    private var statusBadge: some View {
        Text(event.statusDisplay)
            .font(theme.font(11, weight: .semibold))
            .foregroundColor(event.isPast ? .secondary : theme.accentPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(event.isPast ? Color(.systemGray5) : theme.accentTint)
            .cornerRadius(6)
    }
    
    private var formattedDateTime: String {
        guard let startDate = event.startDate else {
            return event.startISO
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if it's today
        if calendar.isDateInToday(startDate) {
            return "Today at \(formatTime(startDate))"
        }
        
        // Check if it's tomorrow
        if calendar.isDateInTomorrow(startDate) {
            return "Tomorrow at \(formatTime(startDate))"
        }
        
        // Check if it's within this week
        if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now),
           startDate < weekFromNow {
            let weekday = startDate.formatted(.dateTime.weekday(.wide))
            return "\(weekday) at \(formatTime(startDate))"
        }
        
        // Otherwise show full date
        return startDate.formatted(date: .abbreviated, time: .shortened)
    }
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    // MARK: - Actions
    
    private func openInCalendar() {
        // Try to open in Calendar app using event identifier
        if event.eventIdentifier != nil {
            // Calendar URL scheme: calshow:[event_start_date]
            // Since we can't directly open a specific event, we'll open the Calendar app
            // at the date of the event
            if let startDate = event.startDate {
                let timestamp = startDate.timeIntervalSinceReferenceDate
                if let url = URL(string: "calshow:\(timestamp)") {
                    openURL(url)
                    return
                }
            }
        }
        
        // Fallback: just open Calendar app
        if let url = URL(string: "calshow://") {
            openURL(url)
        }
    }
}
