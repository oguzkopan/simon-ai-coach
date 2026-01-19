//
//  GoogleSignInService.swift
//  Simon
//
//  Created on 2026-01-19.
//

import Foundation
import FirebaseAuth

@MainActor
final class GoogleSignInService {
    private let provider = OAuthProvider(providerID: "google.com")
    
    init() {
        // Configure Google OAuth provider
        provider.scopes = ["email", "profile"]
        // Optional: Add custom parameters if needed
        // provider.customParameters = ["prompt": "select_account"]
    }
    
    func signIn() async throws -> OAuthCredential {
        // Use Firebase's OAuth flow for Google Sign-In
        let result = try await provider.credential(with: nil)
        
        guard let credential = result as? OAuthCredential else {
            throw AuthError.invalidCredential
        }
        
        return credential
    }
}
