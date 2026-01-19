//
//  AuthSession.swift
//  Simon
//
//  Created on 2026-01-19.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import Combine

struct AuthState {
    let isSignedIn: Bool
    let uid: String?
    let displayName: String?
    let email: String?
    let photoURL: URL?
}

protocol AuthSessionProviding {
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    var currentUser: User? { get }
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signInWithGoogle(credential: OAuthCredential) async throws -> User
    func signOut() throws
    func idToken() async throws -> String
}

@MainActor
final class AuthSession: ObservableObject, AuthSessionProviding {
    @Published private(set) var authState: AuthState
    
    private var handle: AuthStateDidChangeListenerHandle?
    private let authStateSubject = PassthroughSubject<AuthState, Never>()
    
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    init() {
        // Initialize with current state
        let user = Auth.auth().currentUser
        self.authState = AuthState(
            isSignedIn: user != nil,
            uid: user?.uid,
            displayName: user?.displayName,
            email: user?.email,
            photoURL: user?.photoURL
        )
        
        // Listen to auth state changes
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            let newState = AuthState(
                isSignedIn: user != nil,
                uid: user?.uid,
                displayName: user?.displayName,
                email: user?.email,
                photoURL: user?.photoURL
            )
            
            Task { @MainActor in
                self.authState = newState
                self.authStateSubject.send(newState)
            }
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle(credential: OAuthCredential) async throws -> User {
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // MARK: - Get ID Token
    
    func idToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthError.notSignedIn
        }
        return try await user.getIDToken()
    }
}

enum AuthError: LocalizedError {
    case notSignedIn
    case tokenRefreshFailed
    case invalidCredential
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .invalidCredential:
            return "Invalid authentication credential"
        case .cancelled:
            return "Sign in was cancelled"
        }
    }
}
