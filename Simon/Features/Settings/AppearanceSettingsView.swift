//
//  AppearanceSettingsView.swift
//  Simon
//
//  Created on Day 17-18: Settings + Customization
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        List {
            ForEach(AppAppearance.allCases, id: \.self) { appearance in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        theme.settings.appearance = appearance
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appearance.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(appearance.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if theme.settings.appearance == appearance {
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
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AppAppearance {
    var description: String {
        switch self {
        case .system:
            return "Matches your device settings"
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(ThemeStore())
    }
}
