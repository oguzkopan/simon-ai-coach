//
//  ThemeTokens.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct ThemeTokens {
    
    // MARK: - Spacing
    
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    
    // MARK: - Corner Radius
    
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 12
    static let radiusCard: CGFloat = 16
    
    // MARK: - Sizes
    
    static let buttonHeight: CGFloat = 52
    static let buttonHeightSmall: CGFloat = 44
    static let chipHeight: CGFloat = 36
    static let tagHeight: CGFloat = 24
    static let iconSize: CGFloat = 24
    static let iconSizeLarge: CGFloat = 32
    static let minTapTarget: CGFloat = 44
    
    // MARK: - Shadows (Light Mode Only)
    
    static let shadowRadius: CGFloat = 12
    static let shadowY: CGFloat = 2
    static let shadowOpacity: CGFloat = 0.06
    
    // MARK: - Semantic Colors
    
    struct SemanticColors {
        let primaryText: Color
        let secondaryText: Color
        let tertiaryText: Color
        let background: Color
        let surface: Color
        let stroke: Color
        
        static let light = SemanticColors(
            primaryText: Color.black,
            secondaryText: Color.black.opacity(0.6),
            tertiaryText: Color.black.opacity(0.4),
            background: Color.white,
            surface: Color(hex: "F5F5F7"),
            stroke: Color.black.opacity(0.1)
        )
        
        static let dark = SemanticColors(
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.6),
            tertiaryText: Color.white.opacity(0.4),
            background: Color.black,
            surface: Color(hex: "1C1C1E"),
            stroke: Color.white.opacity(0.15)
        )
    }
    
    static func semanticColors(for colorScheme: ColorScheme) -> SemanticColors {
        colorScheme == .dark ? .dark : .light
    }
}
