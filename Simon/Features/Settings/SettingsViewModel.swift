//
//  SettingsViewModel.swift
//  Simon
//
//  Created on Day 17-18: Settings + Customization
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var includeContext: Bool = true
    @Published var showPaywall: Bool = false
    @Published var showCustomerCenter: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    
    private let apiClient: SimonAPI
    private let purchases: PurchasesService
    private let authManager = AuthenticationManager.shared
    
    var isPro: Bool {
        purchases.isPro
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    init(apiClient: SimonAPI, purchases: PurchasesService) {
        self.apiClient = apiClient
        self.purchases = purchases
        
        // Load context preference
        loadContextPreference()
    }
    
    func loadContextPreference() {
        includeContext = UserDefaults.standard.bool(forKey: "include_context")
    }
    
    func saveContextPreference() {
        UserDefaults.standard.set(includeContext, forKey: "include_context")
        
        // Also save to backend
        Task {
            do {
                try await apiClient.updateContextPreference(includeContext: includeContext)
            } catch {
                print("Failed to save context preference: \(error)")
            }
        }
    }
    
    func deleteAllData() async {
        isDeleting = true
        errorMessage = nil
        
        do {
            try await apiClient.deleteAllUserData()
            
            // Sign out after deletion
            try authManager.signOut()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isDeleting = false
    }
}
