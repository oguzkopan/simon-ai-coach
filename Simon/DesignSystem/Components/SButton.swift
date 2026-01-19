//
//  SButton.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

enum SButtonStyle {
    case primary
    case secondary
    case tertiary
}

struct SButton: View {
    let title: String
    let style: SButtonStyle
    let isLoading: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.isEnabled) private var isEnabled
    
    init(
        _ title: String,
        style: SButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                } else {
                    Text(title)
                        .font(theme.font(17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(ThemeTokens.radiusLarge)
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled && !isLoading ? 1.0 : 0.4)
    }
    
    private var height: CGFloat {
        style == .primary ? ThemeTokens.buttonHeight : ThemeTokens.buttonHeightSmall
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.accentPrimary
        case .secondary:
            return theme.accentTint
        case .tertiary:
            return Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return theme.accentPrimary
        case .tertiary:
            return theme.accentPrimary
        }
    }
}

// MARK: - Preview

struct SButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SButton("Primary Button", style: .primary) {}
            SButton("Secondary Button", style: .secondary) {}
            SButton("Tertiary Button", style: .tertiary) {}
            SButton("Loading", style: .primary, isLoading: true) {}
        }
        .padding()
        .environmentObject(ThemeStore())
    }
}
