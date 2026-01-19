//
//  SCard.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct SCard<Content: View>: View {
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(backgroundColor)
            .cornerRadius(ThemeTokens.radiusCard)
            .if(colorScheme == .light) { view in
                view.shadow(
                    color: Color.black.opacity(ThemeTokens.shadowOpacity),
                    radius: ThemeTokens.shadowRadius,
                    x: 0,
                    y: ThemeTokens.shadowY
                )
            }
            .if(colorScheme == .dark) { view in
                view.overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.radiusCard)
                        .stroke(ThemeTokens.semanticColors(for: colorScheme).stroke, lineWidth: 1)
                )
            }
    }
    
    private var backgroundColor: Color {
        ThemeTokens.semanticColors(for: colorScheme).surface
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

struct SCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Title")
                        .font(.headline)
                    Text("Card content goes here")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(ThemeTokens.spacing12)
            }
            .padding()
            .preferredColorScheme(.light)
            
            SCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Title")
                        .font(.headline)
                    Text("Card content goes here")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(ThemeTokens.spacing12)
            }
            .padding()
            .preferredColorScheme(.dark)
            .background(Color.black)
        }
    }
}
