import Foundation
import AVFoundation
import Combine


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
        print("🎵 Starting new audio session")
        audioQueue.removeAll()
        isPlaying = false
        error = nil
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else {
            error = "Failed to create audio engine"
            return
        }
        
        engine.attach(player)
        
        // Use a standard format that matches typical MP3 output
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
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
        
        // Set isPlaying when first chunk arrives
        if !isPlaying {
            isPlaying = true
            print("🔊 Audio playback started (first chunk received)")
        }
        
        // Process queue if not already processing
        if !isProcessing {
            processQueue()
        }
    }
    
    /// Mark that the final audio chunk has been received
    func markFinalChunk() {
        print("🎵 Final audio marker received - stopping playback indicator")
        isPlaying = false
    }
    
    private func processQueue() {
        guard !audioQueue.isEmpty else {
            isProcessing = false
            print("🎵 Audio queue empty, processing complete")
            return
        }
        
        isProcessing = true
        
        // Get next chunk
        let audioData = audioQueue.removeFirst()
        
        // Play the chunk
        playAudioData(audioData) { [weak self] in
            self?.processQueue()
        }
    }
    
    private func playAudioData(_ data: Data, completion: @escaping () -> Void) {
        guard let player = playerNode, let engine = audioEngine else {
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
            
            // Get the engine's output format
            let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
            
            // Create converter if formats don't match
            let needsConversion = audioFile.processingFormat.sampleRate != outputFormat.sampleRate ||
                                 audioFile.processingFormat.channelCount != outputFormat.channelCount
            
            if needsConversion {
                
                // Read entire file into buffer
                let frameCount = AVAudioFrameCount(audioFile.length)
                guard let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: frameCount
                ) else {
                    print("❌ Failed to create input buffer")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                    return
                }
                
                try audioFile.read(into: inputBuffer)
                
                // Create output buffer with engine format
                let outputFrameCapacity = AVAudioFrameCount(
                    Double(inputBuffer.frameLength) * outputFormat.sampleRate / audioFile.processingFormat.sampleRate
                )
                
                guard let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: outputFrameCapacity
                ) else {
                    print("❌ Failed to create output buffer")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                    return
                }
                
                // Convert
                guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: outputFormat) else {
                    print("❌ Failed to create audio converter")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                    return
                }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return inputBuffer
                }
                
                converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("❌ Conversion error: \(error)")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                    return
                }
                
                // Schedule converted buffer
                player.scheduleBuffer(outputBuffer) {
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                }
            } else {
                // No conversion needed - use original format
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
                    try? FileManager.default.removeItem(at: tempURL)
                    completion()
                }
            }
            
        } catch {
            print("❌ Failed to play audio chunk: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            completion()
        }
    }
    
    /// End the streaming session
    func endSession() {
        print("🎵 Ending audio session")
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
