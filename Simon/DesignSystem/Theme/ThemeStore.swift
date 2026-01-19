//
//  ThemeStore.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import Combine

@MainActor
final class ThemeStore: ObservableObject {
    @Published var settings: ThemeSettings {
        didSet { persist() }
    }
    
    private let key = "theme.settings.v1"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ThemeSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = ThemeSettings()
        }
    }
    
    // MARK: - Color Helpers
    
    var accentPrimary: Color {
        settings.colorStack.primaryColor
    }
    
    var accentMuted: Color {
        settings.colorStack.mutedColor
    }
    
    var accentTint: Color {
        settings.colorStack.tintColor
    }
    
    var accentTintDark: Color {
        settings.colorStack.tintColorDark
    }
    
    // MARK: - Font Helpers
    
    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = size * settings.textScale.multiplier
        return .system(size: scaledSize, weight: weight, design: settings.fontTheme.fontDesign)
    }
    
    // MARK: - Typography Roles
    
    var titleFont: Font {
        font(28, weight: .bold)
    }
    
    var sectionHeaderFont: Font {
        font(17, weight: .semibold)
    }
    
    var bodyFont: Font {
        font(15, weight: .regular)
    }
    
    var captionFont: Font {
        font(13, weight: .regular)
    }
    
    var microFont: Font {
        font(11, weight: .regular)
    }
    
    // MARK: - Color Scheme Override
    
    func colorSchemeOverride() -> ColorScheme? {
        switch settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    // MARK: - Persistence
    
    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
