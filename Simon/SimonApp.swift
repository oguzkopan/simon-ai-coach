//
//  SimonApp.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import RevenueCat
import AppIntents

@main
struct SimonApp: App {
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Firebase initialization
        FirebaseApp.configure()
        
        // RevenueCat initialization
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: "appl_jUOcBOAodBWrctklDLzWLLQJeDv")
        
        // Register app shortcuts
        SimonShortcuts.updateAppShortcutParameters()
        
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeStore)
                .environmentObject(deepLinkHandler)
                .preferredColorScheme(themeStore.colorSchemeOverride())
                .onOpenURL { url in
                    // Handle Google Sign-In URL callback
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    
                    // Handle deep links
                    deepLinkHandler.handle(url: url)
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            print("App became active")
            
        case .inactive:
            // App became inactive (transitioning)
            print("App became inactive")
            
        case .background:
            // App entered background - schedule background tasks
            print("App entered background")
            BackgroundTaskManager.shared.scheduleAppRefresh()
            BackgroundTaskManager.shared.scheduleProcessing()
            
        @unknown default:
            break
        }
    }
}

// MARK: - Deep Link Handler

@MainActor
final class DeepLinkHandler: ObservableObject {
    @Published var eventsDeepLink: EventsDeepLink?
    
    func handle(url: URL) {
        // Handle simon://events deep links
        // Format: simon://events?coach_id=<id>&status=<status>&tab=<tab>
        guard url.scheme == "simon" else { return }
        
        if url.host == "events" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let coachID = components?.queryItems?.first(where: { $0.name == "coach_id" })?.value
            let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
            let tabString = components?.queryItems?.first(where: { $0.name == "tab" })?.value
            
            let tab: EventTab
            if let tabString = tabString {
                switch tabString {
                case "reminders":
                    tab = .reminders
                case "notifications":
                    tab = .notifications
                default:
                    tab = .calendar
                }
            } else {
                tab = .calendar
            }
            
            eventsDeepLink = EventsDeepLink(
                coachID: coachID,
                status: status,
                tab: tab
            )
        }
    }
    
    func clearEventsDeepLink() {
        eventsDeepLink = nil
    }
}

struct EventsDeepLink: Equatable {
    let coachID: String?
    let status: String?
    let tab: EventTab
}
