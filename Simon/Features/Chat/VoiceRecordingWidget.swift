import SwiftUI
import AVFoundation

/// Voice recording widget with waveform visualization and playback controls
struct VoiceRecordingWidget: View {
    @ObservedObject var recordingManager: VoiceRecordingManager
    @EnvironmentObject private var theme: ThemeStore
    
    let onSend: (RecordedAudio) -> Void
    let onCancel: () -> Void
    
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            // Waveform Visualization
            WaveformView(levels: recordingManager.audioLevels, isRecording: recordingManager.isRecording)
                .frame(height: 80)
                .padding(.horizontal, 20)
            
            // Duration Display
            Text(formatDuration(recordingManager.duration))
                .font(theme.font(24, weight: .semibold))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            // Recording Status
            if recordingManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: recordingManager.isRecording
                        )
                    Text("Recording...")
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                }
            } else if let recordedAudio = recordingManager.recordedAudio {
                // Playback Controls
                HStack(spacing: 20) {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(theme.accentPrimary)
                    }
                    
                    // Playback Progress
                    VStack(spacing: 4) {
                        ProgressView(value: playbackProgress, total: 1.0)
                            .tint(theme.accentPrimary)
                        
                        HStack {
                            Text(formatDuration(playbackProgress * recordedAudio.duration))
                                .font(theme.font(11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDuration(recordedAudio.duration))
                                .font(theme.font(11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                // Cancel/Delete Button
                Button(action: handleCancel) {
                    HStack(spacing: 8) {
                        Image(systemName: recordingManager.isRecording ? "xmark" : "trash")
                            .font(.system(size: 18, weight: .semibold))
                        Text(recordingManager.isRecording ? "Cancel" : "Delete")
                            .font(theme.font(16, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Stop/Send Button
                Button(action: handlePrimaryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: recordingManager.isRecording ? "stop.fill" : "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(recordingManager.isRecording ? "Stop" : "Send")
                            .font(theme.font(16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.accentPrimary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
    }
    
    // MARK: - Actions
    
    private func handlePrimaryAction() {
        if recordingManager.isRecording {
            // Stop recording
            Task {
                do {
                    print("🎤 Stopping recording...")
                    let audio = try await recordingManager.stopRecording()
                    print("✅ Recording stopped successfully")
                    // Prepare for playback
                    await MainActor.run {
                        prepareAudioPlayer(url: audio.fileURL)
                    }
                } catch {
                    print("❌ Failed to stop recording: \(error)")
                    await MainActor.run {
                        recordingManager.errorMessage = "Failed to stop recording: \(error.localizedDescription)"
                    }
                    // Cancel on error
                    await recordingManager.cancelRecording()
                    onCancel()
                }
            }
        } else {
            // Send recording
            if let audio = recordingManager.recordedAudio {
                stopPlayback()
                onSend(audio)
            }
        }
    }
    
    private func handleCancel() {
        stopPlayback()
        
        if recordingManager.isRecording {
            Task {
                await recordingManager.cancelRecording()
                onCancel()
            }
        } else {
            // Delete recorded audio
            if let url = recordingManager.recordedAudio?.fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            onCancel()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func prepareAudioPlayer(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("❌ Failed to prepare audio player: \(error)")
        }
    }
    
    private func startPlayback() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        
        // Start progress timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let player = audioPlayer {
                playbackProgress = player.currentTime / player.duration
                
                if !player.isPlaying {
                    stopPlayback()
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
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [Float]
    let isRecording: Bool
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<levels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: barWidth(geometry: geometry), height: barHeight(for: index, geometry: geometry))
                        .animation(.easeInOut(duration: 0.1), value: levels[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = CGFloat(levels.count - 1) * 2
        return (geometry.size.width - totalSpacing) / CGFloat(levels.count)
    }
    
    private func barHeight(for index: Int, geometry: GeometryProxy) -> CGFloat {
        let level = levels[index]
        let minHeight: CGFloat = 4
        let maxHeight = geometry.size.height
        return minHeight + (maxHeight - minHeight) * CGFloat(level)
    }
    
    private func barColor(for index: Int) -> Color {
        // Gradient effect: recent bars are brighter
        let recencyFactor = Float(index) / Float(levels.count)
        let opacity = isRecording ? 0.3 + (0.7 * recencyFactor) : 0.5
        return theme.accentPrimary.opacity(Double(opacity))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        VoiceRecordingWidget(
            recordingManager: {
                let manager = VoiceRecordingManager()
                manager.isRecording = true
                manager.duration = 12.34
                manager.audioLevels = (0..<50).map { _ in Float.random(in: 0...1) }
                return manager
            }(),
            onSend: { _ in },
            onCancel: { }
        )
    }
    .environmentObject(ThemeStore())
}
