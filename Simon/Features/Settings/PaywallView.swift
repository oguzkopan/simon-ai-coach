//
//  PaywallView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(theme.accentPrimary)
                    
                    Text("Upgrade to Pro")
                        .font(theme.font(28, weight: .bold))
                    
                    Text("Build systems that stick")
                        .font(theme.font(17))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "infinity",
                        title: "Unlimited Moments",
                        description: "Get guidance whenever you need it"
                    )
                    
                    FeatureRow(
                        icon: "square.and.arrow.up",
                        title: "Publish & Share Coaches",
                        description: "Share your custom coaches with the community"
                    )
                    
                    FeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Turn Advice into Systems",
                        description: "Advanced system mode with schedules and metrics"
                    )
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: Implement purchase flow (Week 3)
                        dismiss()
                    }) {
                        Text("Start Pro")
                            .font(theme.font(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .background(theme.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Button("Not now") {
                        dismiss()
                    }
                    .font(theme.font(15))
                    .foregroundColor(theme.accentPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.font(15, weight: .semibold))
                
                Text(description)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
            }
        }
    }
}
