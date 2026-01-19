//
//  ColorThemePickerView.swift
//  Simon
//
//  Created on Day 17-18: Settings + Customization
//

import SwiftUI

struct ColorThemePickerView: View {
    @EnvironmentObject private var theme: ThemeStore
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview Section
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        // Primary button preview
                        Button(action: {}) {
                            Text("Primary Button")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(theme.accentPrimary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(true)
                        
                        // Secondary button preview
                        Button(action: {}) {
                            Text("Secondary Button")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(theme.accentTint)
                                .foregroundColor(theme.accentPrimary)
                                .cornerRadius(12)
                        }
                        .disabled(true)
                        
                        // Chip preview
                        HStack {
                            ForEach(["Focus", "Planning", "Systems"], id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(theme.accentTint)
                                    .foregroundColor(theme.accentPrimary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                // Color Grid
                VStack(spacing: 16) {
                    Text("Choose Accent Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(ColorStack.allCases, id: \.self) { stack in
                            ColorStackButton(
                                stack: stack,
                                isSelected: theme.settings.colorStack == stack
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    theme.settings.colorStack = stack
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorStackButton: View {
    let stack: ColorStack
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stack.primaryColor)
                        .frame(width: 60, height: 60)
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.primary, lineWidth: 3)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(stack.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ColorThemePickerView()
            .environmentObject(ThemeStore())
    }
}
