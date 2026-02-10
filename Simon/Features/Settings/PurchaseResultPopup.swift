//
//  PurchaseResultPopup.swift
//  Simon
//
//  Created on 2026-02-10.
//

import SwiftUI

struct PurchaseResultPopup: View {
    let isSuccess: Bool
    let message: String
    let onDismiss: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(isSuccess ? .green : .red)
            }
            
            // Title
            Text(isSuccess ? "Success!" : "Purchase Failed")
                .font(theme.font(24, weight: .bold))
                .foregroundColor(.primary)
            
            // Message
            Text(message)
                .font(theme.font(15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
            
            // Button (only for errors)
            if !isSuccess {
                Button(action: onDismiss) {
                    Text("OK")
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(theme.accentPrimary)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: 320)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}
