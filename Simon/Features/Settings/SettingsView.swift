//
//  SettingsView.swift
//  Simon
//
//  Complete redesign matching reference mockup
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var vm: SettingsViewModel
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    init(vm: SettingsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Show sign-in section if not authenticated
                    if !authManager.isAuthenticated {
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(theme.accentPrimary)
                                
                                Text("Sign in to save your preferences")
                                    .font(theme.font(17, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Your appearance settings will be synced across all your devices.")
                                    .font(theme.font(14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }
                            .padding(.top, 20)
                            
                            VStack(spacing: 12) {
                                // Apple Sign In Button
                                Button(action: {
                                    Task {
                                        do {
                                            try await authManager.signInWithApple()
                                        } catch {
                                            vm.errorMessage = error.localizedDescription
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Continue with Apple")
                                            .font(theme.font(16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.black)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                // Google Sign In Button
                                Button(action: {
                                    Task {
                                        do {
                                            try await authManager.signInWithGoogle()
                                        } catch {
                                            vm.errorMessage = error.localizedDescription
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "g.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Continue with Google")
                                            .font(theme.font(16, weight: .semibold))
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider()
                                .padding(.vertical, 12)
                        }
                    }
                    
                    // Preview Section (always visible)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PREVIEW")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SYSTEM UPDATE")
                                    .font(theme.font(11, weight: .semibold))
                                    .foregroundColor(theme.accentPrimary)
                                    .tracking(0.5)
                                
                                Text("Focus on systems, not goals.")
                                    .font(theme.font(24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("You do not rise to the level of your goals. You fall to the level of your systems.")
                                    .font(theme.font(15))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        }
                        
                        // Theme Section (always visible)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("THEME")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            HStack(spacing: 12) {
                                ThemeButton(title: "System", isSelected: theme.settings.appearance == .system) {
                                    theme.settings.appearance = .system
                                }
                                ThemeButton(title: "Light", isSelected: theme.settings.appearance == .light) {
                                    theme.settings.appearance = .light
                                }
                                ThemeButton(title: "Dark", isSelected: theme.settings.appearance == .dark) {
                                    theme.settings.appearance = .dark
                                }
                            }
                        }
                        
                        // Accent Color Section (always visible)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ACCENT COLOR")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            HStack(spacing: 12) {
                                Spacer()
                                ColorButton(color: Color(hex: "5856D6"), isSelected: theme.settings.colorStack == .indigo) {
                                    theme.settings.colorStack = .indigo
                                }
                                ColorButton(color: Color(hex: "30B0C7"), isSelected: theme.settings.colorStack == .teal) {
                                    theme.settings.colorStack = .teal
                                }
                                ColorButton(color: Color(hex: "00C7BE"), isSelected: theme.settings.colorStack == .mint) {
                                    theme.settings.colorStack = .mint
                                }
                                ColorButton(color: Color(hex: "FF9500"), isSelected: theme.settings.colorStack == .orange) {
                                    theme.settings.colorStack = .orange
                                }
                                ColorButton(color: Color(hex: "FF2D55"), isSelected: theme.settings.colorStack == .rose) {
                                    theme.settings.colorStack = .rose
                                }
                                ColorButton(color: Color(hex: "AF52DE"), isSelected: theme.settings.colorStack == .purple) {
                                    theme.settings.colorStack = .purple
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Typography Section (always visible)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("FONT STYLE")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            HStack(spacing: 12) {
                                FontStyleButton(title: "System", fontTheme: .system, isSelected: theme.settings.fontTheme == .system) {
                                    theme.settings.fontTheme = .system
                                }
                                FontStyleButton(title: "Rounded", fontTheme: .rounded, isSelected: theme.settings.fontTheme == .rounded) {
                                    theme.settings.fontTheme = .rounded
                                }
                                FontStyleButton(title: "Serif", fontTheme: .serif, isSelected: theme.settings.fontTheme == .serif) {
                                    theme.settings.fontTheme = .serif
                                }
                            }
                        }
                        
                        // Text Size Section (always visible)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("TEXT SIZE")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("A")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("A")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 0) {
                                    ForEach([TextScale.small, TextScale.medium, TextScale.large, TextScale.extraLarge], id: \.self) { scale in
                                        Button(action: {
                                            theme.settings.textScale = scale
                                        }) {
                                            Circle()
                                                .fill(theme.settings.textScale == scale ? theme.accentPrimary : Color(.systemGray5))
                                                .frame(width: 12, height: 12)
                                                .padding(12)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if scale != .extraLarge {
                                            Rectangle()
                                                .fill(Color(.systemGray5))
                                                .frame(height: 2)
                                        }
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        theme.settings.textScale = .small
                                    }) {
                                        Text("Small")
                                            .font(theme.font(11))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        theme.settings.textScale = .medium
                                    }) {
                                        Text("Medium")
                                            .font(theme.font(11))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        theme.settings.textScale = .large
                                    }) {
                                        Text("Large")
                                            .font(theme.font(11))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        theme.settings.textScale = .extraLarge
                                    }) {
                                        Text("X-Large")
                                            .font(theme.font(11))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        }
                        
                        // Account Section (only when authenticated)
                        if authManager.isAuthenticated {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ACCOUNT")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            VStack(spacing: 12) {
                                Button(action: {
                                    vm.showLogoutConfirmation = true
                                }) {
                                    HStack {
                                        Text("Sign Out")
                                            .font(theme.font(15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(16)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    vm.showDeleteConfirmation = true
                                }) {
                                    HStack {
                                        Text("Delete Account")
                                            .font(theme.font(15, weight: .semibold))
                                            .foregroundColor(.red)
                                        Spacer()
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .padding(16)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // About Section (always visible)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ABOUT")
                                .font(theme.font(11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Version")
                                        .font(theme.font(15))
                                    Spacer()
                                    Text(vm.appVersion)
                                        .font(theme.font(15))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                
                                Divider()
                                
                                Link(destination: URL(string: "https://simon.app/terms")!) {
                                    HStack {
                                        Text("Terms of Service")
                                            .font(theme.font(15))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(16)
                                }
                                
                                Divider()
                                
                                Link(destination: URL(string: "https://simon.app/privacy")!) {
                                    HStack {
                                        Text("Privacy Policy")
                                            .font(theme.font(15))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(16)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(theme.colorSchemeOverride())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .alert("Sign Out", isPresented: $vm.showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                vm.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $vm.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteAccount()
                }
            }
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") {
                vm.errorMessage = nil
            }
        } message: {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Supporting Components

struct ThemeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.font(15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? theme.accentPrimary : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? theme.accentTint : Color(.systemBackground))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct FontStyleButton: View {
    let title: String
    let fontTheme: FontTheme
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(getFontForTheme(fontTheme, size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(.systemBackground) : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func getFontForTheme(_ fontTheme: FontTheme, size: CGFloat, weight: Font.Weight) -> Font {
        switch fontTheme {
        case .system:
            return .system(size: size, weight: weight)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        }
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: isSelected ? 44 : 40, height: isSelected ? 44 : 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: isSelected ? color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct CustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Manage Subscription")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Manage your subscription through the App Store")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Button("Open App Store") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
