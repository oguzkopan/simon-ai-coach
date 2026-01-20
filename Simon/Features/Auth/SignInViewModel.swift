//
//  SignInViewModel.swift
//  Simon
//
//  Created on 2026-01-19.
//

import Foundation
import Combine

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSignedIn = false
    
    private let authManager = AuthenticationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe auth state from AuthenticationManager
        authManager.$isAuthenticated
            .assign(to: &$isSignedIn)
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                try await authManager.signInWithApple()
                // Success - auth state will update automatically
                isLoading = false
            } catch {
                isLoading = false
                handleError(error)
            }
        }
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle() {
        print("📱 SignInViewModel: Starting Google Sign-In")
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                print("📱 SignInViewModel: Calling authManager.signInWithGoogle()")
                try await authManager.signInWithGoogle()
                print("📱 SignInViewModel: Google Sign-In completed successfully")
                isLoading = false
            } catch {
                print("📱 SignInViewModel: Google Sign-In failed with error: \(error)")
                isLoading = false
                handleError(error)
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if let authError = error as? AuthenticationError {
            switch authError {
            case .cancelled:
                // User cancelled - don't show error
                errorMessage = nil
            default:
                errorMessage = authError.localizedDescription
            }
        } else {
            // Check if user cancelled
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" && nsError.code == 1001 {
                // User cancelled Apple Sign In
                errorMessage = nil
            } else if nsError.domain == "FIRAuthErrorDomain" {
                // Firebase auth error
                errorMessage = "Sign in failed. Please try again."
            } else {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }
}
