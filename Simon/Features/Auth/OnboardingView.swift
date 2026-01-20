import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var currentPage = 0
    @State private var isAnimating = false
    let onComplete: () -> Void
    
    private let pages = OnboardingPage.pages
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    theme.accentTint.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page, isAnimating: isAnimating)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? theme.accentPrimary : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: handleContinue) {
                        HStack {
                            Spacer()
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                                .font(theme.font(17, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(theme.accentPrimary)
                        .cornerRadius(16)
                    }
                    
                    Button(action: onComplete) {
                        Text("Skip")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
        .onChange(of: currentPage) { _, _ in
            // Reset and re-trigger animation for new page
            isAnimating = false
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                isAnimating = true
            }
        }
    }
    
    private func handleContinue() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isAnimating: Bool
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon with animated background
            ZStack {
                // Outer glow
                Circle()
                    .fill(theme.accentTint.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 0.6 : 0)
                
                // Middle circle
                Circle()
                    .fill(theme.accentTint.opacity(0.5))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 0.8 : 0)
                
                // Icon container
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 100, height: 100)
                    .shadow(color: theme.accentPrimary.opacity(0.2), radius: 20, x: 0, y: 10)
                    .overlay(
                        Image(systemName: page.icon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(theme.accentPrimary)
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)
            }
            .padding(.top, 40)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(theme.font(28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .opacity(isAnimating ? 1.0 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text(page.description)
                    .font(theme.font(17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .opacity(isAnimating ? 1.0 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            .padding(.horizontal, 32)
        }
        .animation(.easeOut(duration: 0.6), value: isAnimating)
    }
}

// Preview
#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(ThemeStore())
}
