import SwiftUI

/// Animated indicator showing when audio is playing
struct AudioPlayingIndicator: View {
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            animationPhase = 1
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        
        // Create wave pattern
        let phase = animationPhase + CGFloat(index) * 0.3
        let height = baseHeight + (maxHeight - baseHeight) * abs(sin(phase * .pi))
        
        return height
    }
}

/// Compact audio status indicator shown at the top of chat when coach is speaking
struct AudioStatusBar: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 8) {
                AudioPlayingIndicator()
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .scaleEffect(pulseScale)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.12))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

#Preview("Audio Indicator") {
    VStack {
        AudioPlayingIndicator()
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
