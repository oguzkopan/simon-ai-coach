//
//  STextField.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import Combine

struct STextField: View {
    let placeholder: String
    @Binding var text: String
    var maxLines: Int = 1
    
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if maxLines == 1 {
                TextField(placeholder, text: $text)
                    .font(theme.bodyFont)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(theme.bodyFont)
                    .lineLimit(1...maxLines)
                    .focused($isFocused)
            }
        }
        .padding(ThemeTokens.spacing12)
        .background(backgroundColor)
        .cornerRadius(ThemeTokens.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.radiusMedium)
                .stroke(strokeColor, lineWidth: isFocused ? 2 : 1)
        )
    }
    
    private var backgroundColor: Color {
        ThemeTokens.semanticColors(for: colorScheme).surface
    }
    
    private var strokeColor: Color {
        isFocused ? theme.accentPrimary : ThemeTokens.semanticColors(for: colorScheme).stroke
    }
}

// MARK: - Preview

struct STextField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            STextField(placeholder: "Single line", text: .constant(""))
            STextField(placeholder: "Multi line", text: .constant(""), maxLines: 3)
        }
        .padding()
        .environmentObject(ThemeStore())
    }
}
