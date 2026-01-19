//
//  SBanner.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import SwiftUI

enum BannerType {
    case error
    case warning
    case info
    case offline
    
    var backgroundColor: Color {
        switch self {
        case .error: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .info: return Color.blue.opacity(0.1)
        case .offline: return Color.gray.opacity(0.1)
        }
    }
    
    var textColor: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .offline: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .offline: return "wifi.slash"
        }
    }
}

struct SBanner: View {
    let type: BannerType
    let message: String
    let action: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @EnvironmentObject private var theme: ThemeStore
    
    init(
        type: BannerType,
        message: String,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.type = type
        self.message = message
        self.action = action
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20))
                .foregroundColor(type.textColor)
            
            Text(message)
                .font(theme.font(15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            if let action = action {
                Button(action: action) {
                    Text("Retry")
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
            }
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(type.backgroundColor)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Predefined Banners

extension SBanner {
    static func offline(onRetry: @escaping () -> Void) -> SBanner {
        SBanner(
            type: .offline,
            message: "No connection. Some features unavailable.",
            action: onRetry
        )
    }
    
    static func rateLimited(cooldownSeconds: Int) -> SBanner {
        SBanner(
            type: .warning,
            message: "Too many requests. Try again in \(cooldownSeconds)s."
        )
    }
    
    static func tokenExpired(onReauth: @escaping () -> Void) -> SBanner {
        SBanner(
            type: .error,
            message: "Session expired. Please sign in again.",
            action: onReauth
        )
    }
    
    static func error(_ message: String, onRetry: (() -> Void)? = nil) -> SBanner {
        SBanner(
            type: .error,
            message: message,
            action: onRetry
        )
    }
}

#Preview("Error") {
    VStack {
        SBanner.error("Failed to load coaches", onRetry: {})
        Spacer()
    }
    .environmentObject(ThemeStore())
}

#Preview("Offline") {
    VStack {
        SBanner.offline(onRetry: {})
        Spacer()
    }
    .environmentObject(ThemeStore())
}
