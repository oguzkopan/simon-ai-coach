//
//  SLoading.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import SwiftUI

// MARK: - Loading Spinner

struct SLoadingSpinner: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: theme.accentPrimary))
    }
}

// MARK: - Skeleton Loading

struct SSkeletonView: View {
    @State private var isAnimating = false
    @EnvironmentObject private var theme: ThemeStore
    
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Skeleton Card

struct SSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SSkeletonView(width: 32, height: 32, cornerRadius: 16)
                
                VStack(alignment: .leading, spacing: 6) {
                    SSkeletonView(width: 120, height: 16)
                    SSkeletonView(width: 200, height: 14)
                }
            }
            
            SSkeletonView(height: 14)
            SSkeletonView(width: 150, height: 14)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Full Screen Loading

struct SFullScreenLoading: View {
    let message: String?
    @EnvironmentObject private var theme: ThemeStore
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            SLoadingSpinner()
            
            if let message = message {
                Text(message)
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview("Spinner") {
    SLoadingSpinner()
        .environmentObject(ThemeStore())
}

#Preview("Skeleton") {
    VStack(spacing: 12) {
        SSkeletonCard()
        SSkeletonCard()
        SSkeletonCard()
    }
    .padding()
}

#Preview("Full Screen") {
    SFullScreenLoading(message: "Loading coaches...")
        .environmentObject(ThemeStore())
}
