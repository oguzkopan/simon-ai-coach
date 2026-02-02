//
//  CalendarEventRow.swift
//  Simon
//
//  Redesigned calendar event row
//

import SwiftUI

struct CalendarEventRow: View {
    let event: CalendarEventRecord
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Date/Time
                    if let startDate = event.startDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(formatDateTime(startDate))
                                .font(theme.font(13))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Location
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.system(size: 12))
                            Text(location)
                                .font(theme.font(13))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // Status Badge
                statusBadge
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
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(event.statusDisplay)
                .font(theme.font(12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var iconColor: Color {
        event.isUpcoming ? .blue : .secondary
    }
    
    private var iconBackgroundColor: Color {
        event.isUpcoming ? Color.blue.opacity(0.1) : Color(.systemGray6)
    }
    
    private var statusColor: Color {
        event.isUpcoming ? .blue : .secondary
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at " + formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at " + formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
}
