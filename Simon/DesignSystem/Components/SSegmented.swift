//
//  SSegmented.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct SSegmented<T: Hashable>: View {
    let options: [T]
    let displayName: (T) -> String
    @Binding var selection: T
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                Button(action: { selection = option }) {
                    Text(displayName(option))
                        .font(theme.font(15, weight: .medium))
                        .foregroundColor(selection == option ? .white : theme.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: ThemeTokens.buttonHeightSmall)
                        .background(selection == option ? theme.accentPrimary : Color.clear)
                        .cornerRadius(ThemeTokens.radiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.accentTint)
        .cornerRadius(ThemeTokens.radiusMedium)
    }
}
