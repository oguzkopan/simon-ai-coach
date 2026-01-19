//
//  SignInView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct SignInView: View {
    @StateObject private var viewModel: SignInViewModel
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    init(authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: SignInViewModel(authSession: authSession))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Welcome to Simon")
                        .font(theme.titleFont)
                        .multilineTextAlignment(.center)
                    
                    Text("Minimalist AI coaching in your pocket")
                        .font(theme.bodyFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.horizontal, ThemeTokens.spacing32)
                
                Spacer()
                
                // Sign in buttons
                VStack(spacing: 12) {
                    // Apple Sign In
                    Button(action: { viewModel.signInWithApple() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text("Continue with Apple")
                                .font(theme.font(17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: ThemeTokens.buttonHeight)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(ThemeTokens.radiusLarge)
                    }
                    .disabled(viewModel.isLoading)
                    
                    // Google Sign In
                    Button(action: { viewModel.signInWithGoogle() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text("Continue with Google")
                                .font(theme.font(17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: ThemeTokens.buttonHeight)
                        .foregroundColor(.primary)
                        .background(Color(.systemGray6))
                        .cornerRadius(ThemeTokens.radiusLarge)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, ThemeTokens.spacing16)
                
                // Loading indicator
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, ThemeTokens.spacing16)
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(theme.captionFont)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ThemeTokens.spacing32)
                        .padding(.top, ThemeTokens.spacing16)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(theme.captionFont)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(theme.captionFont)
                        
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(theme.captionFont)
                    }
                }
                .padding(.bottom, ThemeTokens.spacing32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .font(theme.bodyFont)
                    .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .onChange(of: viewModel.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }
}

#Preview {
    SignInView(authSession: AuthSession())
        .environmentObject(ThemeStore())
}
