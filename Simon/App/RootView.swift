//
//  RootView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authSession = AuthSession()
    @EnvironmentObject private var theme: ThemeStore
    
    @State private var showSignIn = false
    
    var body: some View {
        Group {
            if authSession.authState.isSignedIn {
                // Main app (will be implemented in Day 5-7)
                MainTabView()
                    .environmentObject(authSession)
            } else {
                // Browse without sign in (allow browsing)
                MainTabView()
                    .environmentObject(authSession)
                    .sheet(isPresented: $showSignIn) {
                        SignInView(authSession: authSession)
                    }
            }
        }
        .onAppear {
            // Show sign in on first launch (optional)
            // For now, users can browse without signing in
        }
    }
}

// MARK: - Main Tab View (Placeholder for Day 5-7)

struct MainTabView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var authSession: AuthSession
    
    @State private var selectedTab = 0
    @State private var showSignIn = false
    @StateObject private var purchasesService = PurchasesService()
    
    // Create API client
    private var apiClient: SimonAPIClient {
        SimonAPIClient(baseURL: URL(string: "http://localhost:8080")!)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Browse Tab
            NavigationStack {
                BrowseView()
            }
            .tabItem {
                Label("Browse", systemImage: "square.grid.2x2")
            }
            .tag(0)
            
            // Moment Tab
            NavigationStack {
                MomentView(vm: MomentViewModel(
                    apiClient: apiClient,
                    purchases: purchasesService
                ))
            }
            .tabItem {
                Label("Moment", systemImage: "bolt.fill")
            }
            .tag(1)
            
            // Library Tab
            NavigationStack {
                LibraryView(vm: LibraryViewModel(
                    apiClient: apiClient
                ))
            }
            .tabItem {
                Label("Library", systemImage: "book.fill")
            }
            .tag(2)
        }
        .tint(theme.accentPrimary)
        .sheet(isPresented: $showSignIn) {
            SignInView(authSession: authSession)
        }
    }
}

// MARK: - Placeholder Views (Will be implemented in Day 5-7)

struct BrowseView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var authSession: AuthSession
    
    @State private var showSignIn = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Browse")
                        .font(theme.titleFont)
                    
                    Text("Pick a coach and start instantly.")
                        .font(theme.bodyFont)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ThemeTokens.spacing16)
                
                // Auth status indicator
                if authSession.authState.isSignedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Signed in as \(authSession.authState.displayName ?? authSession.authState.email ?? "User")")
                            .font(theme.captionFont)
                        Spacer()
                        Button("Sign Out") {
                            try? authSession.signOut()
                        }
                        .font(theme.captionFont)
                        .foregroundColor(theme.accentPrimary)
                    }
                    .padding(ThemeTokens.spacing12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(ThemeTokens.radiusMedium)
                    .padding(.horizontal, ThemeTokens.spacing16)
                } else {
                    Button(action: { showSignIn = true }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Sign in to save your progress")
                                .font(theme.captionFont)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ThemeTokens.spacing12)
                        .background(theme.accentTint)
                        .foregroundColor(theme.accentPrimary)
                        .cornerRadius(ThemeTokens.radiusMedium)
                    }
                    .padding(.horizontal, ThemeTokens.spacing16)
                }
                
                Text("Browse screen will be implemented in Day 5-7")
                    .font(theme.bodyFont)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .padding(.vertical, ThemeTokens.spacing16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignIn) {
            SignInView(authSession: authSession)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ThemeStore())
}
