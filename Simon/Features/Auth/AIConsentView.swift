//
//  AIConsentView.swift
//  Simon
//
//  Created on 2026-02-22.
//

import SwiftUI

struct AIConsentView: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var hasAccepted = false
    
    let onAccept: () -> Void
    
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
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(theme.accentTint.opacity(0.3))
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 80, height: 80)
                            .shadow(color: theme.accentPrimary.opacity(0.2), radius: 20, x: 0, y: 10)
                            .overlay(
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 36))
                                    .foregroundColor(theme.accentPrimary)
                            )
                    }
                    .padding(.bottom, 16)
                    
                    // Title
                    Text("AI-Powered Coaching")
                        .font(theme.font(32, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text("Saimon uses advanced AI technology to provide personalized coaching. Here's how your data is processed:")
                        .font(theme.font(17))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                    
                    // Data sharing information
                    VStack(spacing: 16) {
                        DataSharingRow(
                            icon: "brain.head.profile",
                            title: "Google Vertex AI (Gemini)",
                            description: "Your messages, voice transcriptions, and uploaded images are sent to Google's Vertex AI to generate personalized coaching responses."
                        )
                        
                        DataSharingRow(
                            icon: "waveform",
                            title: "ElevenLabs",
                            description: "When you enable voice-over, your coach's text responses are sent to ElevenLabs to generate natural-sounding speech."
                        )
                        
                        DataSharingRow(
                            icon: "lock.shield",
                            title: "Your Privacy",
                            description: "All data is encrypted in transit. These services process your data only to provide coaching features and do not use it for other purposes."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    
                    // Privacy policy link
                    Link(destination: URL(string: "https://simon-7a833.web.app/privacy")!) {
                        Text("Read our full Privacy Policy")
                            .font(theme.font(15))
                            .foregroundColor(theme.accentPrimary)
                            .underline()
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    // Consent checkbox
                    Button(action: {
                        hasAccepted.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: hasAccepted ? "checkmark.square.fill" : "square")
                                .font(.system(size: 24))
                                .foregroundColor(hasAccepted ? theme.accentPrimary : .secondary)
                            
                            Text("I understand and consent to sharing my data with Google Vertex AI and ElevenLabs for AI coaching features")
                                .font(theme.font(15))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Continue button
                    Button(action: {
                        // Save consent
                        UserDefaults.standard.set(true, forKey: "hasAcceptedAIConsent")
                        onAccept()
                    }) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(theme.font(17, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(hasAccepted ? theme.accentPrimary : Color(.systemGray4))
                        .cornerRadius(16)
                    }
                    .disabled(!hasAccepted)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
}

struct DataSharingRow: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(theme.font(14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    AIConsentView(onAccept: {})
        .environmentObject(ThemeStore())
}
