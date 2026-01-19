//
//  TypographySettingsView.swift
//  Simon
//
//  Created on Day 17-18: Settings + Customization
//

import SwiftUI

struct TypographySettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        List {
            ForEach(FontTheme.allCases, id: \.self) { fontTheme in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        theme.settings.fontTheme = fontTheme
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(fontTheme.displayName)
                                .font(fontTheme.previewFont(size: 17))
                                .foregroundColor(.primary)
                            
                            Text("The quick brown fox jumps over the lazy dog")
                                .font(fontTheme.previewFont(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if theme.settings.fontTheme == fontTheme {
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.accentPrimary)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TextSizeSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 24) {
            // Preview
            VStack(spacing: 16) {
                Text("Preview")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screen Title")
                        .font(theme.font(28, weight: .bold))
                    
                    Text("This is body text that shows how your content will look at the selected size.")
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                    
                    Text("Caption text for metadata")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            // Size Options
            VStack(spacing: 12) {
                Text("Text Size")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ForEach(TextScale.allCases, id: \.self) { scale in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            theme.settings.textScale = scale
                        }
                    } label: {
                        HStack {
                            Text(scale.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(scale.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if theme.settings.textScale == scale {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.accentPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .navigationTitle("Text Size")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension FontTheme {
    func previewFont(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size)
        case .rounded:
            return .system(size: size, design: .rounded)
        case .serif:
            return .system(size: size, design: .serif)
        }
    }
}

extension TextScale {
    var description: String {
        switch self {
        case .small:
            return "Compact"
        case .medium:
            return "Default"
        case .large:
            return "Comfortable"
        case .extraLarge:
            return "Spacious"
        }
    }
}

#Preview("Typography") {
    NavigationStack {
        TypographySettingsView()
            .environmentObject(ThemeStore())
    }
}

#Preview("Text Size") {
    NavigationStack {
        TextSizeSettingsView()
            .environmentObject(ThemeStore())
    }
}
