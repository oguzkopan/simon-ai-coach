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
    
    private let authSession: AuthSession
    private let appleSignInService = AppleSignInService()
    private let googleSignInService = GoogleSignInService()
    private var cancellables = Set<AnyCancellable>()
    
    init(authSession: AuthSession) {
        self.authSession = authSession
        
        // Observe auth state
        authSession.authStatePublisher
            .map { $0.isSignedIn }
            .assign(to: &$isSignedIn)
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let result = try await appleSignInService.signIn()
                _ = try await authSession.signInWithApple(
                    idToken: result.idToken,
                    nonce: result.nonce
                )
                
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
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let credential = try await googleSignInService.signIn()
                _ = try await authSession.signInWithGoogle(credential: credential)
                
                // Success - auth state will update automatically
                isLoading = false
            } catch {
                isLoading = false
                handleError(error)
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if let authError = error as? AuthError {
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
            } else if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                // User cancelled Google Sign In
                errorMessage = nil
            } else {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }
}
