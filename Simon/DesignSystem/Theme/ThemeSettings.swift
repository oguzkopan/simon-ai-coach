//
//  ThemeSettings.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import Combine

// MARK: - App Appearance

enum AppAppearance: String, Codable, CaseIterable {
    case system
    case light
    case dark
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Color Stack

enum ColorStack: String, Codable, CaseIterable {
    case indigo
    case teal
    case mint
    case orange
    case rose
    case purple
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var primaryColor: Color {
        switch self {
        case .indigo: return Color(hex: "5856D6")
        case .teal: return Color(hex: "30B0C7")
        case .mint: return Color(hex: "00C7BE")
        case .orange: return Color(hex: "FF9500")
        case .rose: return Color(hex: "FF2D55")
        case .purple: return Color(hex: "AF52DE")
        }
    }
    
    var mutedColor: Color {
        switch self {
        case .indigo: return Color(hex: "7C7AE8")
        case .teal: return Color(hex: "5AC8DB")
        case .mint: return Color(hex: "32D9D1")
        case .orange: return Color(hex: "FFB340")
        case .rose: return Color(hex: "FF6482")
        case .purple: return Color(hex: "C77EE8")
        }
    }
    
    var tintColor: Color {
        primaryColor.opacity(0.06)
    }
    
    var tintColorDark: Color {
        primaryColor.opacity(0.10)
    }
}

// MARK: - Font Theme

enum FontTheme: String, Codable, CaseIterable {
    case system
    case rounded
    case serif
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        }
    }
    
    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }
}

// MARK: - Text Scale

enum TextScale: String, Codable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge
    
    var displayName: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        }
    }
    
    var multiplier: CGFloat {
        switch self {
        case .small: return 0.92
        case .medium: return 1.0
        case .large: return 1.08
        case .extraLarge: return 1.18
        }
    }
}

// MARK: - Theme Settings

struct ThemeSettings: Codable, Equatable {
    var appearance: AppAppearance = .system
    var colorStack: ColorStack = .indigo
    var fontTheme: FontTheme = .system
    var textScale: TextScale = .medium
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
