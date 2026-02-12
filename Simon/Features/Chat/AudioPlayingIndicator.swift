import SwiftUI

/// Animated indicator showing when audio is playing with frequency visualization
struct AudioPlayingIndicator: View {
    let audioLevels: [CGFloat]
    @State private var animationPhase: CGFloat = 0
    
    init(audioLevels: [CGFloat] = []) {
        self.audioLevels = audioLevels.isEmpty ? [0.3, 0.6, 0.4, 0.7, 0.5] : audioLevels
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.08),
                        value: animationPhase
                    )
            }
        }
        .frame(height: 24)
        .onAppear {
            animationPhase = 1
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 24
        
        // Use audio levels if available, otherwise create wave pattern
        let level = index < audioLevels.count ? audioLevels[index] : 0.5
        
        // Create animated wave pattern
        let phase = animationPhase + CGFloat(index) * 0.4
        let animatedLevel = abs(sin(phase * .pi * 2))
        
        // Combine audio level with animation
        let combinedLevel = (level * 0.6) + (animatedLevel * 0.4)
        let height = baseHeight + (maxHeight - baseHeight) * combinedLevel
        
        return max(baseHeight, min(maxHeight, height))
    }
}

/// Compact audio status indicator shown at the top of chat when coach is speaking
struct AudioStatusBar: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 10) {
                AudioPlayingIndicator()
                
                Text("Coach is speaking")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .scaleEffect(pulseScale)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue.opacity(0.12))
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0),
                                    Color.blue.opacity(0.15),
                                    Color.blue.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerPhase)
                        .mask(RoundedRectangle(cornerRadius: 24))
                }
            )
            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 2)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            // Pulse animation for speaker icon
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
            
            // Shimmer animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 200
            }
        }
    }
}

#Preview("Audio Indicator") {
    VStack {
        AudioPlayingIndicator()
            .padding()
        
        AudioPlayingIndicator(audioLevels: [0.8, 0.4, 0.9, 0.3, 0.7])
            .padding()
        
        Spacer()
    }
}

#Preview("Audio Status Bar") {
    VStack {
        AudioStatusBar()
        Spacer()
    }
}
