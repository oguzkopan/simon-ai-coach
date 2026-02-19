//
//  OnboardingSignInView.swift
//  Simon
//
//  Created on 2026-02-19.
//

import SwiftUI
import FirebaseAuth

struct OnboardingSignInView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    let onSkip: () -> Void
    let onSignInComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    theme.accentPrimary.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon with animated background
                ZStack {
                    Circle()
                        .fill(theme.accentTint.opacity(0.3))
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .fill(theme.accentTint.opacity(0.5))
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 80, height: 80)
                        .shadow(color: theme.accentPrimary.opacity(0.2), radius: 20, x: 0, y: 10)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(theme.accentPrimary)
                        )
                }
                .padding(.bottom, 32)
                
                // Title and description
                VStack(spacing: 12) {
                    Text("Save your progress")
                        .font(theme.font(32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Sign in to sync your coaches, sessions, and preferences across all your devices.")
                        .font(theme.font(17))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(theme.font(14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }
                
                // Sign-in buttons
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await signInWithApple()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Continue with Apple")
                                    .font(theme.font(17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        Task {
                            await signInWithGoogle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Continue with Google")
                                    .font(theme.font(17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Skip button
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(theme.font(16))
                        .foregroundColor(.secondary)
                }
                .disabled(isLoading)
                .padding(.bottom, 48)
            }
        }
    }
    
    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.signInWithApple()
            onSignInComplete()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.signInWithGoogle()
            onSignInComplete()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    OnboardingSignInView(
        onSkip: {},
        onSignInComplete: {}
    )
    .environmentObject(ThemeStore())
}
