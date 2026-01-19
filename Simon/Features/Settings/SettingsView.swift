//
//  SettingsView.swift
//  Simon
//
//  Created on Day 17-18: Settings + Customization
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(vm: SettingsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance
                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Text(theme.settings.appearance.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        ColorThemePickerView()
                    } label: {
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            Circle()
                                .fill(theme.accentPrimary)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                
                // Text
                Section("Text") {
                    NavigationLink {
                        TypographySettingsView()
                    } label: {
                        HStack {
                            Text("Font")
                            Spacer()
                            Text(theme.settings.fontTheme.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        TextSizeSettingsView()
                    } label: {
                        HStack {
                            Text("Text Size")
                            Spacer()
                            Text(theme.settings.textScale.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Subscription
                Section("Subscription") {
                    if vm.isPro {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Pro")
                                .foregroundColor(theme.accentPrimary)
                                .fontWeight(.semibold)
                        }
                        
                        Button("Manage Subscription") {
                            vm.showCustomerCenter = true
                        }
                    } else {
                        Button("Upgrade to Pro") {
                            vm.showPaywall = true
                        }
                        .foregroundColor(theme.accentPrimary)
                    }
                }
                
                // Privacy
                Section("Privacy") {
                    Toggle("Include Context in Coaching", isOn: $vm.includeContext)
                        .onChange(of: vm.includeContext) {
                            vm.saveContextPreference()
                        }
                    
                    Button("Delete All Data", role: .destructive) {
                        vm.showDeleteConfirmation = true
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(vm.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Terms of Service", destination: URL(string: "https://simon.app/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://simon.app/privacy")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $vm.showCustomerCenter) {
            CustomerCenterView()
        }
        .alert("Delete All Data", isPresented: $vm.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteAllData()
                }
            }
        } message: {
            Text("This will permanently delete all your data including coaches, sessions, and systems. This action cannot be undone.")
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

#Preview {
    SettingsView(vm: SettingsViewModel(
        apiClient: SimonAPIClient(baseURL: URL(string: "http://localhost:8080")!),
        purchases: PurchasesService(),
        authSession: AuthSession()
    ))
    .environmentObject(ThemeStore())
}
