import Foundation
import AVFoundation
import Combine

#if os(iOS)
/// AudioStreamPlayer handles real-time streaming audio playback
/// Decodes base64 MP3 chunks and plays them sequentially with minimal latency
@MainActor
class AudioStreamPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var error: String?
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioQueue: [Data] = []
    private var isProcessing = false
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            self.error = "Audio setup failed"
        }
    }
    
    /// Start a new streaming session
    func startSession() {
        print("🎵 Starting audio stream session")
        audioQueue.removeAll()
        isPlaying = true
        error = nil
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else {
            error = "Failed to create audio engine"
            return
        }
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
            player.play()
            print("✅ Audio engine started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            self.error = "Failed to start audio playback"
        }
    }
    
    /// Add an audio chunk to the playback queue
    func enqueueAudioChunk(_ base64Audio: String) {
        guard !base64Audio.isEmpty else { return }
        
        // Decode base64
        guard let audioData = Data(base64Encoded: base64Audio) else {
            print("❌ Failed to decode base64 audio")
            return
        }
        
        print("🎵 Enqueued audio chunk: \(audioData.count) bytes")
        audioQueue.append(audioData)
        
        // Process queue if not already processing
        if !isProcessing {
            processQueue()
        }
    }
    
    private func processQueue() {
        guard !audioQueue.isEmpty else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        
        // Get next chunk
        let audioData = audioQueue.removeFirst()
        
        // Play the chunk
        playAudioData(audioData) { [weak self] in
            // Continue processing queue
            self?.processQueue()
        }
    }
    
    private func playAudioData(_ data: Data, completion: @escaping () -> Void) {
        guard let player = playerNode else {
            completion()
            return
        }
        
        // Create temporary file for MP3 data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        
        do {
            try data.write(to: tempURL)
            
            // Load audio file
            let audioFile = try AVAudioFile(forReading: tempURL)
            let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            )
            
            guard let buffer = buffer else {
                try? FileManager.default.removeItem(at: tempURL)
                completion()
                return
            }
            
            try audioFile.read(into: buffer)
            
            // Schedule buffer for playback
            player.scheduleBuffer(buffer) {
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                completion()
            }
            
            print("✅ Scheduled audio buffer: \(buffer.frameLength) frames")
            
        } catch {
            print("❌ Failed to play audio chunk: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            completion()
        }
    }
    
    /// End the streaming session
    func endSession() {
        print("🎵 Ending audio stream session")
        
        playerNode?.stop()
        audioEngine?.stop()
        
        playerNode = nil
        audioEngine = nil
        audioQueue.removeAll()
        isPlaying = false
        isProcessing = false
    }
    
    /// Stop playback immediately
    func stop() {
        endSession()
    }
}
#else
// Stub for non-iOS platforms
@MainActor
class AudioStreamPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var error: String?
    
    func startSession() {}
    func enqueueAudioChunk(_ base64Audio: String) {}
    func endSession() {}
    func stop() {}
}
#endif
