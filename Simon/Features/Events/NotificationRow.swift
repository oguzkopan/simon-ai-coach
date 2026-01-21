//
//  NotificationRow.swift
//  Simon
//
//  Created for Event Persistence feature
//

import SwiftUI

struct NotificationRow: View {
    let notification: ScheduledNotificationRecord
    let onCancel: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @State private var showingCancelConfirmation = false
    
    var body: some View {
        SCard {
            HStack(spacing: ThemeTokens.spacing12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: ThemeTokens.radiusSmall)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(notification.title)
                        .font(theme.font(16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Body
                    Text(notification.body)
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Trigger time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(notification.triggerDescription)
                            .font(theme.font(13))
                    }
                    .foregroundColor(.secondary)
                    
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
                
                // Status and actions
                VStack(spacing: 8) {
                    statusBadge
                    
                    if notification.isScheduled {
                        Button(action: {
                            showingCancelConfirmation = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(ThemeTokens.spacing12)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if notification.isScheduled {
                Button(role: .destructive, action: {
                    showingCancelConfirmation = true
                }) {
                    Label("Cancel", systemImage: "xmark")
                }
            }
        }
        .confirmationDialog(
            "Cancel Notification",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Notification", role: .destructive) {
                onCancel()
            }
            Button("Keep Notification", role: .cancel) {}
        } message: {
            Text("Cancel the notification '\(notification.title)'? You won't receive this notification.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch notification.status {
        case "scheduled":
            return "bell.badge"
        case "delivered":
            return "bell.fill"
        case "cancelled":
            return "bell.slash"
        default:
            return "bell"
        }
    }
    
    private var iconColor: Color {
        switch notification.status {
        case "scheduled":
            return theme.accentPrimary
        case "delivered":
            return .green
        case "cancelled":
            return .gray
        default:
            return .secondary
        }
    }
    
    private var statusBadge: some View {
        Text(notification.statusDisplay)
            .font(theme.font(11, weight: .semibold))
            .foregroundColor(statusTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusBackgroundColor)
            .cornerRadius(6)
    }
    
    private var statusTextColor: Color {
        switch notification.status {
        case "scheduled":
            return theme.accentPrimary
        case "delivered":
            return .green
        case "cancelled":
            return .secondary
        default:
            return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        switch notification.status {
        case "scheduled":
            return theme.accentTint
        case "delivered":
            return Color.green.opacity(0.15)
        case "cancelled":
            return Color(.systemGray5)
        default:
            return Color(.systemGray5)
        }
    }
}
