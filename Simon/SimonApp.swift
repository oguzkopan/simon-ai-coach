//
//  SimonApp.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import FirebaseCore
import RevenueCat

@main
struct SimonApp: App {
    @StateObject private var themeStore = ThemeStore()
    
    init() {
        // Firebase initialization
        FirebaseApp.configure()
        
        // RevenueCat initialization
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_YOUR_DEBUG_KEY")
        #else
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: "appl_YOUR_PRODUCTION_KEY")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeStore)
                .preferredColorScheme(themeStore.colorSchemeOverride())
        }
    }
}
