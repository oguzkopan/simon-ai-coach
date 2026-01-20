//
//  SimonApp.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import RevenueCat

@main
struct SimonApp: App {
    @StateObject private var themeStore = ThemeStore()
    
    init() {
        // Firebase initialization
        FirebaseApp.configure()
        
        // RevenueCat initialization
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: "appl_jUOcBOAodBWrctklDLzWLLQJeDv")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeStore)
                .preferredColorScheme(themeStore.colorSchemeOverride())
                .onOpenURL { url in
                    // Handle Google Sign-In URL callback
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
