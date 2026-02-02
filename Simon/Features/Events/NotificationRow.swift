//
//  NotificationRow.swift
//  Simon
//
//  Redesigned notification row
//

import SwiftUI

struct NotificationRow: View {
    let notification: ScheduledNotificationRecord
    let onCancel: () -> Void
    @EnvironmentObject private var theme: ThemeStore
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(notification.body)
                    .font(theme.font(14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Trigger time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(notification.triggerDescription)
                            .font(theme.font(13))
                    }
                    .foregroundColor(.secondary)
                    
                    // Status badge
                    statusBadge
                }
            }
            
            Spacer()
            
            // Cancel button (only for scheduled)
            if notification.isScheduled {
                Button {
                    showCancelConfirmation = true
                } label: {
                    if isCancelling {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                .disabled(isCancelling)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(notification.isCancelled ? 0.6 : 1.0)
        .confirmationDialog(
            "Cancel Notification",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Notification", role: .destructive) {
                isCancelling = true
                onCancel()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this notification?")
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(notification.statusDisplay)
                .font(theme.font(12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var iconName: String {
        if notification.isDelivered {
            return "bell.badge.fill"
        } else if notification.isCancelled {
            return "bell.slash.fill"
        } else {
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        if notification.isDelivered {
            return .green
        } else if notification.isCancelled {
            return .secondary
        } else {
            return .purple
        }
    }
    
    private var iconBackgroundColor: Color {
        if notification.isDelivered {
            return Color.green.opacity(0.1)
        } else if notification.isCancelled {
            return Color(.systemGray6)
        } else {
            return Color.purple.opacity(0.1)
        }
    }
    
    private var statusColor: Color {
        if notification.isDelivered {
            return .green
        } else if notification.isCancelled {
            return .secondary
        } else {
            return .purple
        }
    }
}
