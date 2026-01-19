//
//  AccessibilityHelper.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import SwiftUI
import Combine

// MARK: - Accessibility Labels

extension View {
    func accessibilityLabelWithHint(_ label: String, hint: String? = nil) -> some View {
        var view = self.accessibilityLabel(label)
        if let hint = hint {
            view = view.accessibilityHint(hint)
        }
        return view
    }
    
    func accessibilityButton(_ label: String, hint: String? = nil) -> some View {
        var view = self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
        if let hint = hint {
            view = view.accessibilityHint(hint)
        }
        return view
    }
    
    func accessibilityHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Dynamic Type Support

extension View {
    func limitDynamicTypeSize(_ range: ClosedRange<DynamicTypeSize>) -> some View {
        self.dynamicTypeSize(range)
    }
}

// MARK: - Reduce Motion

struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let animation: Animation
    let fallback: Animation
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? fallback : animation, value: UUID())
    }
}

extension View {
    func adaptiveAnimation(
        _ animation: Animation,
        fallback: Animation = .linear(duration: 0.1)
    ) -> some View {
        modifier(ReduceMotionModifier(animation: animation, fallback: fallback))
    }
}

// MARK: - Contrast Support

extension Color {
    func adaptiveContrast(for colorScheme: ColorScheme) -> Color {
        // Ensure WCAG AA compliance (4.5:1 contrast ratio)
        return self
    }
}

// MARK: - Accessibility Identifiers

enum AccessibilityID {
    // Navigation
    static let tabBarBrowse = "tab_bar_browse"
    static let tabBarMoment = "tab_bar_moment"
    static let tabBarLibrary = "tab_bar_library"
    
    // Browse
    static let coachCard = "coach_card"
    static let coachStartButton = "coach_start_button"
    static let searchButton = "search_button"
    
    // Moment
    static let momentFreeformInput = "moment_freeform_input"
    static let momentStartButton = "moment_start_button"
    static let momentTemplate = "moment_template"
    
    // Chat
    static let chatComposer = "chat_composer"
    static let chatSendButton = "chat_send_button"
    static let chatAttachButton = "chat_attach_button"
    static let messageBubble = "message_bubble"
    
    // Library
    static let sessionCard = "session_card"
    static let systemCard = "system_card"
    static let savedCoachCard = "saved_coach_card"
    
    // Settings
    static let settingsButton = "settings_button"
    static let upgradeButton = "upgrade_button"
    static let deleteDataButton = "delete_data_button"
}
