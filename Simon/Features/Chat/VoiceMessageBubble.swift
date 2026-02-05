import SwiftUI
import AVFoundation

/// Voice message bubble with playback controls
struct VoiceMessageBubble: View {
    let audioURL: String
    let duration: TimeInterval?
    let isUser: Bool
    
    @EnvironmentObject private var theme: ThemeStore
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    @State private var isLoading = false
    @State private var loadError: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(isUser ? Color.white.opacity(0.2) : theme.accentPrimary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    if isLoading {
                        ProgressView()
                            .tint(isUser ? .white : theme.accentPrimary)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isUser ? .white : theme.accentPrimary)
                    }
                }
            }
            .disabled(isLoading || loadError != nil)
            
            // Waveform and Progress
            VStack(alignment: .leading, spacing: 4) {
                // Simple waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isUser ? Color.white.opacity(0.6) : theme.accentPrimary.opacity(0.4))
                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                            .opacity(playbackProgress > Double(index) / 20.0 ? 1.0 : 0.4)
                    }
                }
                .frame(height: 24)
                
                // Duration / Progress
                if let error = loadError {
                    Text(error)
                        .font(theme.font(10))
                        .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                } else {
                    Text(formatTime(playbackProgress * (duration ?? 0)))
                        .font(theme.font(10))
                        .foregroundColor(isUser ? .white.opacity(0.7) : .secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(isUser ? theme.accentPrimary : Color(.systemGray6))
        .cornerRadius(16)
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        // If player already exists, just resume
        if let player = audioPlayer {
            player.play()
            isPlaying = true
            startProgressTimer()
            return
        }
        
        // Load audio from URL
        isLoading = true
        loadError = nil
        
        print("🎵 VoiceMessageBubble: Starting playback for URL: \(audioURL)")
        
        guard let url = URL(string: audioURL) else {
            print("❌ VoiceMessageBubble: Invalid URL: \(audioURL)")
            loadError = "Invalid URL"
            isLoading = false
            return
        }
        
        Task {
            do {
                print("🎵 VoiceMessageBubble: Downloading audio from: \(url)")
                // Download audio data
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎵 VoiceMessageBubble: HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        throw NSError(domain: "VoiceMessageBubble", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                    }
                }
                
                print("🎵 VoiceMessageBubble: Downloaded \(data.count) bytes")
                
                // Create temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("wav")
                
                try data.write(to: tempURL)
                print("🎵 VoiceMessageBubble: Wrote to temp file: \(tempURL)")
                
                // Create player
                await MainActor.run {
                    do {
                        // Configure audio session for playback
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                        try AVAudioSession.sharedInstance().setActive(true)
                        
                        let player = try AVAudioPlayer(contentsOf: tempURL)
                        player.prepareToPlay()
                        audioPlayer = player
                        
                        print("🎵 VoiceMessageBubble: Player created, duration: \(player.duration)s")
                        
                        player.play()
                        isPlaying = true
                        isLoading = false
                        startProgressTimer()
                    } catch {
                        print("❌ VoiceMessageBubble: Playback failed: \(error)")
                        loadError = "Playback failed"
                        isLoading = false
                    }
                }
            } catch {
                print("❌ VoiceMessageBubble: Download failed: \(error)")
                await MainActor.run {
                    loadError = "Download failed"
                    isLoading = false
                }
            }
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }
    
    private func startProgressTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let player = audioPlayer {
                playbackProgress = player.currentTime / player.duration
                
                if !player.isPlaying {
                    stopPlayback()
                    playbackProgress = 0
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
