import SwiftUI

/// Animated typing indicator showing the coach is thinking
struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Coach avatar placeholder (small)
            Circle()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            
            // Typing indicator bubble
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(uiColor: .systemGray3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            // Start animation cycle
            withAnimation {
                animationPhase = 1
            }
            
            // Cycle through dots
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
                withAnimation {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

/// Alternative typing indicator with pulsing effect
struct TypingIndicatorPulseView: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Coach avatar placeholder (small)
            Circle()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            
            // Pulsing bubble
            HStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(20)
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            isPulsing = true
        }
    }
}

/// Minimal typing indicator with just dots
struct TypingIndicatorMinimalView: View {
    @State private var dotCount = 1
    @State private var timer: Timer?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Dots only
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index < dotCount ? Color(uiColor: .systemGray3) : Color(uiColor: .systemGray5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotCount = dotCount % 3 + 1
            }
        }
    }
}

// MARK: - Preview

struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Standard Typing Indicator")
                .font(.caption)
            TypingIndicatorView()
            
            Text("Pulse Typing Indicator")
                .font(.caption)
            TypingIndicatorPulseView()
            
            Text("Minimal Typing Indicator")
                .font(.caption)
            TypingIndicatorMinimalView()
        }
        .padding()
    }
}
