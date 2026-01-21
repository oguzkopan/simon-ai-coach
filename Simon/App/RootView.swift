//
//  RootView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    
    @State private var showSignIn = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showEventsView = false
    
    // Create API client
    private var apiClient: SimonAPIClient {
        SimonAPIClient(
            baseURL: URL(string: "https://simon-api-pl6ewfkpvq-uc.a.run.app")!
        )
    }
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOnboarding = false
                    }
                }
            } else if authManager.isAuthenticated {
                // Main app (will be implemented in Day 5-7)
                MainTabView()
            } else {
                // Browse without sign in (allow browsing)
                MainTabView()
                    .sheet(isPresented: $showSignIn) {
                        SignInView()
                    }
            }
        }
        .sheet(isPresented: $showEventsView) {
            NavigationStack {
                if let deepLink = deepLinkHandler.eventsDeepLink {
                    EventsView(vm: EventsViewModel(
                        apiClient: apiClient,
                        initialCoachFilter: deepLink.coachID
                    ))
                    .onAppear {
                        // Apply deep link filters
                        // The view model will handle the initial filters
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showEventsView = false
                                deepLinkHandler.clearEventsDeepLink()
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: deepLinkHandler.eventsDeepLink) { oldValue, newValue in
            if newValue != nil {
                showEventsView = true
            }
        }
    }
}

// MARK: - Main Tab View (Placeholder for Day 5-7)

struct MainTabView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var selectedTab = 0
    @State private var showSignIn = false
    @State private var browseNavigationPath = NavigationPath()
    @StateObject private var purchasesService = PurchasesService()
    
    // Create API client
    private var apiClient: SimonAPIClient {
        SimonAPIClient(
            baseURL: URL(string: "https://simon-api-pl6ewfkpvq-uc.a.run.app")!
        )
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Browse Tab
            NavigationStack(path: $browseNavigationPath) {
                BrowseView(
                    onNavigateToCoach: { coach in
                        browseNavigationPath.append(CoachDestination.detail(coach))
                    }
                )
                .navigationDestination(for: CoachDestination.self) { destination in
                    switch destination {
                    case .detail(let coach):
                        CoachDetailView(
                            coach: coach,
                            apiClient: apiClient,
                            onStartChat: { sessionId in
                                browseNavigationPath.append(CoachDestination.chat(sessionId: sessionId, coachName: coach.title))
                            }
                        )
                    case .chat(let sessionId, let coachName):
                        ChatView(viewModel: ChatViewModel(
                            sessionID: sessionId,
                            coachName: coachName,
                            apiClient: apiClient
                        ))
                    }
                }
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
                let libraryVM = LibraryViewModel(apiClient: apiClient)
                LibraryView(vm: libraryVM)
                    .onAppear {
                        // Set up navigation callbacks
                        libraryVM.onNavigateToChat = { sessionId in
                            // Switch to browse tab and navigate
                            selectedTab = 0
                            browseNavigationPath.append(CoachDestination.chat(sessionId: sessionId, coachName: "Coach"))
                        }
                        libraryVM.onNavigateToMoment = {
                            selectedTab = 1 // Switch to Moment tab
                        }
                        libraryVM.onNavigateToSettings = {
                            // TODO: Show settings
                            print("Show settings")
                        }
                        libraryVM.onShowAllSessions = {
                            // TODO: Show all sessions view
                            print("Show all sessions")
                        }
                    }
            }
            .tabItem {
                Label("Library", systemImage: "book.fill")
            }
            .tag(2)
        }
        .tint(theme.accentPrimary)
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}

// Navigation destination for coach and chat
enum CoachDestination: Hashable {
    case detail(Coach)
    case chat(sessionId: String, coachName: String)
    
    static func == (lhs: CoachDestination, rhs: CoachDestination) -> Bool {
        switch (lhs, rhs) {
        case (.detail(let lCoach), .detail(let rCoach)):
            return lCoach.id == rCoach.id
        case (.chat(let lSessionId, let lCoachName), .chat(let rSessionId, let rCoachName)):
            return lSessionId == rSessionId && lCoachName == rCoachName
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .detail(let coach):
            hasher.combine("detail")
            hasher.combine(coach.id)
        case .chat(let sessionId, let coachName):
            hasher.combine("chat")
            hasher.combine(sessionId)
            hasher.combine(coachName)
        }
    }
}

// MARK: - Browse View with Settings

struct BrowseView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var purchasesService = PurchasesService()
    
    @State private var showSignIn = false
    @State private var showSettings = false
    
    var onNavigateToCoach: ((Coach) -> Void)?
    
    // Create API client
    private var apiClient: SimonAPIClient {
        SimonAPIClient(
            baseURL: URL(string: "https://simon-api-pl6ewfkpvq-uc.a.run.app")!
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom top bar with header and profile icon
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browse")
                        .font(theme.font(34, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Pick a coach and start instantly.")
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showSettings = true
                }) {
                    if authManager.isAuthenticated {
                        // Show profile picture or initial
                        if let photoURL = authManager.currentUser?.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(theme.accentTint)
                                    .overlay(
                                        Text(authManager.currentUser?.displayName?.prefix(1).uppercased() ?? "U")
                                            .font(theme.font(15, weight: .semibold))
                                            .foregroundColor(theme.accentPrimary)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(theme.accentTint)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(authManager.currentUser?.displayName?.prefix(1).uppercased() ?? "U")
                                        .font(theme.font(15, weight: .semibold))
                                        .foregroundColor(theme.accentPrimary)
                                )
                        }
                    } else {
                        Circle()
                            .fill(theme.accentPrimary.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(theme.accentPrimary)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
            
            // Main content
            HomeView(
                viewModel: HomeViewModel(apiClient: apiClient),
                onCoachTap: { coach in
                    onNavigateToCoach?(coach)
                }
            )
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(vm: SettingsViewModel(
                apiClient: apiClient,
                purchases: purchasesService
            ))
            .environmentObject(theme)
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}

// MARK: - Sign In Prompt View

struct SignInPromptView: View {
    @Binding var showSignIn: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(theme.accentTint)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 36))
                    .foregroundColor(theme.accentPrimary)
            }
            .padding(.top, 20)
            
            // Title and message
            VStack(spacing: 12) {
                Text("Save your progress")
                    .font(theme.font(24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Create an account to keep your favorite coaches and session history synced across all your devices.")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(theme.font(13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        isLoading = true
                        errorMessage = nil
                        do {
                            try await authManager.signInWithApple()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            isLoading = false
                        }
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Apple")
                                .font(theme.font(17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        errorMessage = nil
                        do {
                            try await authManager.signInWithGoogle()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            isLoading = false
                        }
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(theme.font(17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 20)
            
            // Not now button
            Button(action: {
                dismiss()
            }) {
                Text("Not now")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
            }
            .disabled(isLoading)
            .padding(.bottom, 20)
        }
    }
}
