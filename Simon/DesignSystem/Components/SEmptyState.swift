//
//  SEmptyState.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import SwiftUI

struct SEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?
    
    @EnvironmentObject private var theme: ThemeStore
    
    init(
        icon: String,
        title: String,
        message: String,
        primaryAction: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(theme.accentMuted)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)
            
            if let primaryAction = primaryAction {
                VStack(spacing: 12) {
                    Button(action: primaryAction.action) {
                        Text(primaryAction.title)
                            .font(theme.font(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(theme.accentPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    if let secondaryAction = secondaryAction {
                        Button(action: secondaryAction.action) {
                            Text(secondaryAction.title)
                                .font(theme.font(15))
                                .foregroundColor(theme.accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateAction {
    let title: String
    let action: () -> Void
}

// MARK: - Predefined Empty States

extension SEmptyState {
    static func libraryEmpty(
        onStartMoment: @escaping () -> Void,
        onBrowseCoaches: @escaping () -> Void
    ) -> SEmptyState {
        SEmptyState(
            icon: "books.vertical",
            title: "Your library is empty",
            message: "Start a Moment or browse coaches to begin building your personal coaching library.",
            primaryAction: EmptyStateAction(title: "Start a Moment", action: onStartMoment),
            secondaryAction: EmptyStateAction(title: "Browse Coaches", action: onBrowseCoaches)
        )
    }
    
    static func sessionsEmpty(onStartMoment: @escaping () -> Void) -> SEmptyState {
        SEmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "No conversations yet",
            message: "Start your first coaching moment to begin.",
            primaryAction: EmptyStateAction(title: "Start a Moment", action: onStartMoment)
        )
    }
    
    static func systemsEmpty(onStartChat: @escaping () -> Void) -> SEmptyState {
        SEmptyState(
            icon: "square.grid.2x2",
            title: "No systems yet",
            message: "Pin advice from coaching sessions to create repeatable systems.",
            primaryAction: EmptyStateAction(title: "Start Coaching", action: onStartChat)
        )
    }
    
    static func coachesEmpty(onCreate: @escaping () -> Void) -> SEmptyState {
        SEmptyState(
            icon: "person.crop.circle.badge.plus",
            title: "No coaches yet",
            message: "Create your first custom coach to get started.",
            primaryAction: EmptyStateAction(title: "Create Coach", action: onCreate)
        )
    }
    
    static func searchEmpty(onClearFilters: @escaping () -> Void) -> SEmptyState {
        SEmptyState(
            icon: "magnifyingglass",
            title: "No coaches found",
            message: "Try adjusting your search or filters.",
            primaryAction: EmptyStateAction(title: "Clear Filters", action: onClearFilters)
        )
    }
    
    static func offline() -> SEmptyState {
        SEmptyState(
            icon: "wifi.slash",
            title: "You're offline",
            message: "Some features are unavailable. Connect to the internet to continue."
        )
    }
}

#Preview("Library Empty") {
    SEmptyState.libraryEmpty(
        onStartMoment: {},
        onBrowseCoaches: {}
    )
    .environmentObject(ThemeStore())
}

#Preview("Offline") {
    SEmptyState.offline()
        .environmentObject(ThemeStore())
}
