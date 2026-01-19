//
//  SChip.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct SChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.captionFont)
                .foregroundColor(textColor)
                .padding(.horizontal, ThemeTokens.spacing12)
                .padding(.vertical, ThemeTokens.spacing8)
                .background(backgroundColor)
                .cornerRadius(ThemeTokens.radiusMedium)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        isSelected ? theme.accentPrimary : theme.accentTint
    }
    
    private var textColor: Color {
        isSelected ? .white : theme.accentPrimary
    }
}

struct STagChip: View {
    let title: String
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Text(title)
            .font(theme.microFont)
            .foregroundColor(theme.accentPrimary)
            .padding(.horizontal, ThemeTokens.spacing8)
            .padding(.vertical, 4)
            .background(theme.accentTint)
            .cornerRadius(ThemeTokens.radiusSmall)
    }
}

// MARK: - Preview

struct SChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                SChip(title: "Focus", isSelected: true) {}
                SChip(title: "Planning", isSelected: false) {}
                SChip(title: "Creativity", isSelected: false) {}
            }
            
            HStack(spacing: 8) {
                STagChip(title: "focus")
                STagChip(title: "systems")
            }
        }
        .padding()
        .environmentObject(ThemeStore())
    }
}
