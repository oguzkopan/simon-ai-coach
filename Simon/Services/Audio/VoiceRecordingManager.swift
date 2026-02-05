import Foundation
@preconcurrency import AVFoundation
import Accelerate
import Combine

/// Manages voice recording with real-time audio level monitoring
@MainActor
final class VoiceRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 50) // For waveform visualization
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var recordedAudio: RecordedAudio?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var timer: Timer?
    private var startTime: Date?
    
    // Audio format: 16kHz, 16-bit PCM (required by Gemini)
    private let sampleRate: Double = 16000
    private let channelCount: AVAudioChannelCount = 1
    
    override init() {
        super.init()
    }
    
    /// Start recording audio
    func startRecording() async throws {
        // Request microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw RecordingError.permissionDenied
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)
        
        // Create audio engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        // Get the input format from the microphone
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "voice_\(UUID().uuidString).caf"
        let fileURL = tempDir.appendingPathComponent(filename)
        self.recordingURL = fileURL
        
        // Create audio file with input format (we'll convert later)
        self.audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: inputFormat.settings
        )
        
        // Install tap on input node for real-time monitoring
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Write to file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("❌ Failed to write audio buffer: \(error)")
            }
            
            // Calculate audio levels for visualization
            Task { @MainActor in
                self.updateAudioLevels(from: buffer)
            }
        }
        
        // Start engine
        try engine.start()
        
        // Update state
        await MainActor.run {
            self.isRecording = true
            self.startTime = Date()
            self.startDurationTimer()
        }
    }
    
    /// Stop recording and return the audio data
    func stopRecording() async throws -> RecordedAudio {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        // Stop timer
        timer?.invalidate()
        timer = nil
        
        // Stop engine and remove tap
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Close the audio file to flush all data
        audioFile = nil
        
        // Deactivate audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(false)
        
        // Get recording details
        guard let fileURL = recordingURL else {
            throw RecordingError.noRecordingFound
        }
        
        let duration = self.duration
        
        // Verify file exists and has data
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecordingError.noRecordingFound
        }
        
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        guard fileSize > 0 else {
            throw RecordingError.noRecordingFound
        }
        
        print("✅ Recording saved: \(fileURL.lastPathComponent), size: \(fileSize) bytes, duration: \(duration)s")
        
        // Convert to PCM16 for Gemini
        let pcmData = try convertToPCM16(sourceURL: fileURL)
        
        let recorded = RecordedAudio(
            data: pcmData,
            duration: duration,
            sampleRate: Int(sampleRate),
            fileURL: fileURL
        )
        
        // Update state
        await MainActor.run {
            self.isRecording = false
            self.recordedAudio = recorded
        }
        
        return recorded
    }
    
    /// Cancel recording without saving
    func cancelRecording() async {
        timer?.invalidate()
        timer = nil
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Clean up file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        await MainActor.run {
            self.isRecording = false
            self.duration = 0
            self.audioLevels = Array(repeating: 0.0, count: 50)
            self.recordingURL = nil
            self.recordedAudio = nil
        }
    }
    
    /// Reset the manager state (call after sending)
    func reset() {
        duration = 0
        audioLevels = Array(repeating: 0.0, count: 50)
        recordedAudio = nil
        errorMessage = nil
        
        // Clean up file if exists
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func startDurationTimer() {
        let startTime = self.startTime
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = startTime else { return }
            Task { @MainActor in
                self.duration = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func updateAudioLevels(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square) for audio level
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // Convert to decibels
        let db = 20 * log10(max(rms, 0.00001))
        
        // Normalize to 0-1 range (assuming -60dB to 0dB range)
        let normalized = max(0, min(1, (db + 60) / 60))
        
        // Update levels array (shift left and add new value)
        audioLevels.removeFirst()
        audioLevels.append(normalized)
    }
    
    private func convertToPCM16(sourceURL: URL) throws -> Data {
        // Read the audio file
        let audioFile = try AVAudioFile(forReading: sourceURL)
        
        print("📊 Input format: \(audioFile.processingFormat.sampleRate)Hz, \(audioFile.processingFormat.channelCount) channels")
        
        // Create output format (16kHz, mono, 16-bit PCM)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw RecordingError.invalidFormat
        }
        
        // If already in correct format, just read the data
        if audioFile.processingFormat.sampleRate == sampleRate &&
           audioFile.processingFormat.channelCount == channelCount &&
           audioFile.processingFormat.commonFormat == .pcmFormatInt16 {
            
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
                throw RecordingError.conversionFailed
            }
            
            try audioFile.read(into: buffer)
            
            guard let int16Data = buffer.int16ChannelData else {
                throw RecordingError.conversionFailed
            }
            
            let dataSize = Int(buffer.frameLength) * MemoryLayout<Int16>.size
            return Data(bytes: int16Data[0], count: dataSize)
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: outputFormat) else {
            throw RecordingError.conversionFailed
        }
        
        // Calculate output buffer size
        let inputFrameCount = AVAudioFrameCount(audioFile.length)
        let ratio = outputFormat.sampleRate / audioFile.processingFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputFrameCount) * ratio) + 1024 // Add padding
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            throw RecordingError.conversionFailed
        }
        
        // Read input file
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: inputFrameCount) else {
            throw RecordingError.conversionFailed
        }
        
        try audioFile.read(into: inputBuffer)
        
        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("❌ Conversion error: \(error)")
            throw error
        }
        
        guard status != .error else {
            throw RecordingError.conversionFailed
        }
        
        print("✅ Converted to PCM16: \(outputBuffer.frameLength) frames")
        
        // Extract PCM data
        guard let int16ChannelData = outputBuffer.int16ChannelData else {
            throw RecordingError.conversionFailed
        }
        
        let channelDataPointer = int16ChannelData[0]
        let dataSize = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        let pcmData = Data(bytes: channelDataPointer, count: dataSize)
        
        return pcmData
    }
}

// MARK: - Models

struct RecordedAudio {
    let data: Data // PCM16 audio data
    let duration: TimeInterval
    let sampleRate: Int
    let fileURL: URL
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case invalidFormat
    case notRecording
    case noRecordingFound
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied. Please enable it in Settings."
        case .invalidFormat:
            return "Invalid audio format"
        case .notRecording:
            return "No active recording"
        case .noRecordingFound:
            return "Recording file not found"
        case .conversionFailed:
            return "Failed to convert audio format"
        }
    }
}
