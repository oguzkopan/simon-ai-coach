//
//  MomentViewModel.swift
//  Simon
//
//  Created on Day 12-14: Moment + Router Agent
//

import Foundation
import Combine
import AVFoundation
import PhotosUI
import SwiftUI

struct MomentTemplate: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let prompt: String
}

struct AttachedFile: Identifiable {
    let id = UUID()
    let name: String
    let type: AttachmentType
    let data: Data
    
    enum AttachmentType {
        case image
        case document
    }
}

enum InputMode {
    case text
    case voice
}

@MainActor
final class MomentViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var freeformInput: String = ""
    @Published var selectedTemplate: MomentTemplate?
    @Published var isLoading: Bool = false
    @Published var isLoadingEvents: Bool = false
    @Published var errorMessage: String?
    @Published var showPaywall: Bool = false
    @Published var navigateToChat: Bool = false
    @Published var createdSessionId: String?
    @Published var createdCoachName: String?
    @Published var createdInitialPrompt: String? // Store the first message from backend
    @Published var remainingMoments: Int = 3
    @Published var isRecording: Bool = false
    @Published var routines: [System] = []
    @Published var selectedRoutine: System?
    @Published var showImagePicker: Bool = false
    @Published var showDocumentPicker: Bool = false
    @Published var attachedFiles: [AttachedFile] = []
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var inputMode: InputMode = .voice // Toggle between text and voice (voice is default)
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.3, count: 40) // For waveform visualization
    
    // Audio playback properties
    @Published var hasRecordedAudio: Bool = false
    @Published var isPlayingAudio: Bool = false
    @Published var audioPlaybackPosition: TimeInterval = 0
    @Published var savedAudioDuration: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var recordedAudioURL: URL?
    
    // Event records for display
    @Published var upcomingEvents: [CalendarEventRecord] = []
    @Published var pendingReminders: [ReminderRecord] = []
    @Published var scheduledNotifications: [ScheduledNotificationRecord] = []
    
    // Progress documents (plans, check-ins)
    @Published var activePlans: [Plan] = []
    @Published var recentCheckins: [Checkin] = []
    @Published var isLoadingProgress: Bool = false
    
    // Track if initial load has been done
    private var hasLoadedEvents = false
    private var hasLoadedProgress = false
    
    // Selected items for detail view
    @Published var selectedEvent: CalendarEventRecord?
    @Published var selectedReminder: ReminderRecord?
    @Published var selectedNotification: ScheduledNotificationRecord?
    
    // Sheet states
    @Published var showEventDetail = false
    @Published var showReminderDetail = false
    @Published var showNotificationDetail = false
    
    let apiClient: SimonAPI // Made public for EventsView access
    private let purchases: PurchasesService
    private let eventPersistence: EventPersistenceService
    private let authManager: AuthenticationManager
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    
    var isPro: Bool {
        purchases.isPro
    }
    
    var pendingRoutinesCount: Int {
        routines.filter { routine in
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: routine.createdAt, to: Date()).day ?? 0
            return daysSinceCreation > 0
        }.count
    }
    
    let templates: [MomentTemplate] = [
        MomentTemplate(
            id: "clarify",
            title: "Clarify next step",
            description: "I'm stuck. What should I do next?",
            icon: "arrow.right.circle",
            prompt: "I'm feeling stuck and need help clarifying my next step."
        ),
        MomentTemplate(
            id: "decide",
            title: "Make a decision",
            description: "Help me think through a choice",
            icon: "arrow.triangle.branch",
            prompt: "I need help making a decision."
        ),
        MomentTemplate(
            id: "plan",
            title: "Plan today",
            description: "Structure my day effectively",
            icon: "calendar",
            prompt: "Help me plan my day effectively."
        ),
        MomentTemplate(
            id: "reset",
            title: "Reset after bad day",
            description: "Get back on track",
            icon: "arrow.counterclockwise",
            prompt: "I had a rough day and need help resetting."
        ),
        MomentTemplate(
            id: "system",
            title: "Create a system",
            description: "Turn this into a routine",
            icon: "square.grid.2x2",
            prompt: "I want to create a system or routine for something."
        ),
        MomentTemplate(
            id: "talk",
            title: "Talk it out",
            description: "Just need to process",
            icon: "bubble.left.and.bubble.right",
            prompt: "I just need to talk through what's on my mind."
        )
    ]
    
    init(apiClient: SimonAPI, purchases: PurchasesService) {
        self.apiClient = apiClient
        self.purchases = purchases
        self.eventPersistence = .shared
        self.authManager = .shared
    }
    
    func loadRemainingMoments() async {
        guard !isPro else {
            remainingMoments = -1 // Unlimited
            return
        }
        
        // TODO: Fetch from backend
        // For now, use local count
        let today = Calendar.current.startOfDay(for: Date())
        let key = "moments_count_\(today.timeIntervalSince1970)"
        let count = UserDefaults.standard.integer(forKey: key)
        remainingMoments = max(0, 3 - count)
    }
    
    func loadRoutines() async {
        do {
            routines = try await apiClient.listSystems()
        } catch {
            print("Failed to load routines: \(error)")
        }
    }
    
    func loadUpcomingEvents() async {
        guard let uid = authManager.currentUser?.uid else { return }
        
        // Only show loading skeleton on first load
        if !hasLoadedEvents {
            isLoadingEvents = true
        }
        
        do {
            // Load upcoming calendar events (next 7 days)
            let allEvents = try await eventPersistence.listCalendarEvents(uid: uid, limit: 20)
            upcomingEvents = allEvents.filter { $0.isUpcoming }.prefix(5).map { $0 }
            
            // Load pending reminders
            let allReminders = try await eventPersistence.listReminders(uid: uid, status: "pending", limit: 10)
            pendingReminders = Array(allReminders.prefix(5))
            
            // Load scheduled notifications
            let allNotifications = try await eventPersistence.listScheduledNotifications(uid: uid, status: "scheduled", limit: 10)
            scheduledNotifications = Array(allNotifications.prefix(5))
            
            print("✅ Loaded moment events: calendar=\(upcomingEvents.count), reminders=\(pendingReminders.count), notifications=\(scheduledNotifications.count)")
            
            hasLoadedEvents = true
            isLoadingEvents = false
        } catch {
            print("❌ Failed to load moment events: \(error)")
            hasLoadedEvents = true
            isLoadingEvents = false
        }
    }
    
    func loadProgressDocuments() async {
        guard let uid = authManager.currentUser?.uid else {
            print("❌ No authenticated user for progress documents")
            return
        }
        
        // Only show loading skeleton on first load
        if !hasLoadedProgress {
            isLoadingProgress = true
        }
        
        print("🔍 Loading progress documents for UID: \(uid)")
        
        do {
            // Load active plans
            let plans = try await apiClient.listPlans(status: "active", limit: 3)
            activePlans = plans
            
            // TODO: Add check-ins API endpoint
            // For now, check-ins will be empty
            recentCheckins = []
            
            print("✅ Loaded progress: plans=\(activePlans.count), checkins=\(recentCheckins.count)")
            if activePlans.isEmpty {
                print("⚠️ No active plans found - check backend filtering")
            } else {
                for plan in activePlans {
                    print("  📋 Plan: \(plan.title) (status: \(plan.status), uid: \(plan.uid))")
                }
            }
            
            hasLoadedProgress = true
            isLoadingProgress = false
        } catch {
            print("❌ Failed to load progress documents: \(error)")
            hasLoadedProgress = true
            isLoadingProgress = false
        }
    }
    
    // MARK: - Event Actions
    
    func deleteEvent(_ event: CalendarEventRecord) {
        Task {
            do {
                // Delete from Firestore
                try await eventPersistence.deleteCalendarEvent(eventID: event.id)
                
                // Update local state
                upcomingEvents.removeAll { $0.id == event.id }
                
                print("✅ Deleted calendar event: \(event.id)")
            } catch {
                print("❌ Failed to delete event: \(error)")
                errorMessage = "Failed to delete event"
            }
        }
    }
    
    func deleteReminder(_ reminder: ReminderRecord) {
        Task {
            do {
                // Delete from Firestore
                try await eventPersistence.deleteReminder(reminderID: reminder.id)
                
                // Update local state
                pendingReminders.removeAll { $0.id == reminder.id }
                
                print("✅ Deleted reminder: \(reminder.id)")
            } catch {
                print("❌ Failed to delete reminder: \(error)")
                errorMessage = "Failed to delete reminder"
            }
        }
    }
    
    func deleteNotification(_ notification: ScheduledNotificationRecord) {
        Task {
            do {
                // Cancel notification via API
                _ = try await apiClient.cancelNotification(id: notification.id)
                
                // Update local state
                scheduledNotifications.removeAll { $0.id == notification.id }
                
                print("✅ Cancelled notification: \(notification.id)")
            } catch {
                print("❌ Failed to cancel notification: \(error)")
                errorMessage = "Failed to cancel notification"
            }
        }
    }
    
    func openRoutine(_ routine: System) {
        selectedRoutine = routine
    }
    
    func startTemplate(_ template: MomentTemplate) {
        selectedTemplate = template
        Task {
            await startMoment(prompt: template.prompt)
        }
    }
    
    func startFreeform() {
        guard !freeformInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await startMoment(prompt: freeformInput)
        }
    }
    
    private func startMoment(prompt: String) async {
        // No paywall restrictions - everyone can use moments
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Call backend to create session immediately
            let response = try await apiClient.startMoment(prompt: prompt)
            
            // Navigate to chat immediately
            // The chat will show "Finding the best coach for you..." while streaming
            createdSessionId = response.sessionId
            createdCoachName = response.coachName
            createdInitialPrompt = prompt // Pass the prompt to trigger streaming
            navigateToChat = true
            
            // Reset form
            freeformInput = ""
            selectedTemplate = nil
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func incrementMomentCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "moments_count_\(today.timeIntervalSince1970)"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }
    
    func createChatViewModel(sessionId: String, coachName: String, initialPrompt: String?) -> ChatViewModel {
        return ChatViewModel(
            sessionID: sessionId,
            coachName: coachName,
            apiClient: apiClient,
            initialPrompt: initialPrompt,
            isNewSession: true, // This is a new session from a moment
            purchasesService: purchases
        )
    }
    
    // MARK: - Voice Input
    
    func toggleInputMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            inputMode = inputMode == .text ? .voice : .text
        }
        
        // Stop recording if switching away from voice mode
        if inputMode == .text && isRecording {
            stopVoiceRecording()
        }
    }
    
    func startVoiceRecording() {
        Task {
            do {
                // Request microphone permission
                let permissionGranted = await AVAudioApplication.requestRecordPermission()
                
                guard permissionGranted else {
                    errorMessage = "Microphone permission is required for voice input"
                    return
                }
                
                // Setup audio session
                audioSession = AVAudioSession.sharedInstance()
                try audioSession?.setCategory(.record, mode: .default)
                try audioSession?.setActive(true)
                
                // Setup recorder
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let audioFilename = documentsPath.appendingPathComponent("moment_recording_\(Date().timeIntervalSince1970).m4a")
                
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder?.isMeteringEnabled = true
                audioRecorder?.record()
                
                isRecording = true
                recordingDuration = 0
                
                // Start timers for duration and audio levels
                startRecordingTimers()
                
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isRecording = false
            }
        }
    }
    
    private func startRecordingTimers() {
        // Duration timer (selector-based to avoid @Sendable capture)
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                              target: self,
                                              selector: #selector(recordingTimerFired),
                                              userInfo: nil,
                                              repeats: true)
        RunLoop.main.add(recordingTimer!, forMode: .common)
        
        // Audio level timer for waveform (selector-based)
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(timeInterval: 0.05,
                                          target: self,
                                          selector: #selector(levelTimerFired),
                                          userInfo: nil,
                                          repeats: true)
        RunLoop.main.add(levelTimer!, forMode: .common)
    }
    
    @objc private func recordingTimerFired() {
        recordingDuration += 0.1
    }
    
    @objc private func levelTimerFired() {
        updateAudioLevels()
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        
        // Convert power (-160 to 0) to a normalized value (0.1 to 1.0)
        let normalizedPower = max(0.1, min(1.0, CGFloat((power + 160) / 160)))
        
        // Shift array and add new value
        audioLevels.removeFirst()
        audioLevels.append(normalizedPower)
    }
    
    func stopVoiceRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        
        guard let recordingURL = audioRecorder?.url else {
            print("❌ No recording URL available")
            return
        }
        
        print("✅ Recording stopped - URL: \(recordingURL)")
        print("📊 Recording duration: \(recordingDuration)")
        
        // Save the recording for playback
        recordedAudioURL = recordingURL
        savedAudioDuration = recordingDuration
        hasRecordedAudio = true
        
        // Prepare audio player
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.delegate = self // Set delegate to detect completion
            audioPlayer?.prepareToPlay()
            
            print("✅ Audio player prepared - duration: \(audioPlayer?.duration ?? 0)")
        } catch {
            print("❌ Failed to prepare audio player: \(error)")
            errorMessage = "Failed to prepare audio for playback"
        }
    }
    
    func playRecordedAudio() {
        guard let player = audioPlayer else {
            print("❌ No audio player available")
            return
        }
        
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to configure audio session for playback: \(error)")
        }
        
        print("▶️ Starting playback - duration: \(player.duration)")
        player.play()
        isPlayingAudio = true
        
        // Start playback timer (selector-based to avoid @Sendable capture)
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                             target: self,
                                             selector: #selector(playbackTimerFired),
                                             userInfo: nil,
                                             repeats: true)
        if let playbackTimer {
            RunLoop.main.add(playbackTimer, forMode: .common)
        }
    }
    
    @objc private func playbackTimerFired() {
        guard let player = audioPlayer else { return }
        audioPlaybackPosition = player.currentTime
        
        // Stop when finished
        if !player.isPlaying && audioPlaybackPosition >= player.duration - 0.1 {
            print("✅ Playback finished")
            stopPlayback()
        }
    }
    
    func pauseRecordedAudio() {
        audioPlayer?.pause()
        isPlayingAudio = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlaybackPosition = 0
        isPlayingAudio = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func toggleAudioPlayback() {
        if isPlayingAudio {
            pauseRecordedAudio()
        } else {
            playRecordedAudio()
        }
    }
    
    func deleteRecordedAudio() {
        stopPlayback()
        
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordedAudioURL = nil
        audioPlayer = nil
        hasRecordedAudio = false
        savedAudioDuration = 0
        audioPlaybackPosition = 0
    }
    
    func cancelVoiceRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
        
        audioRecorder?.stop()
        
        if let recordingURL = audioRecorder?.url {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        
        isRecording = false
        recordingDuration = 0
        audioLevels = Array(repeating: 0.3, count: 40)
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("🎵 Audio playback finished successfully: \(flag)")
            self.stopPlayback()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Audio player decode error: \(error?.localizedDescription ?? "unknown")")
            self.stopPlayback()
        }
    }
    
    func toggleVoiceInput() {
        if isRecording {
            stopVoiceRecording()
        } else {
            startVoiceRecording()
        }
    }
    
    private func transcribeAudio(url: URL) async {
        // TODO: Implement speech-to-text transcription using Speech framework
        // For now, we'll just clean up the audio file
        // In production, you would:
        // 1. Use SFSpeechRecognizer to transcribe the audio
        // 2. Append the transcribed text to freeformInput
        // 3. Handle errors gracefully
        
        // Clean up the audio file
        try? FileManager.default.removeItem(at: url)
        
        // Show a message that transcription is not yet implemented
        errorMessage = "Voice transcription coming soon. Please type your message for now."
    }
    
    // MARK: - Attachment
    
    func showAttachmentPicker() {
        showImagePicker = true
    }
    
    func handlePhotoSelection() {
        guard let item = selectedPhotoItem else { return }
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let file = AttachedFile(
                        name: "image_\(Date().timeIntervalSince1970).jpg",
                        type: .image,
                        data: data
                    )
                    attachedFiles.append(file)
                }
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
            }
            selectedPhotoItem = nil
        }
    }
    
    func removeAttachment(_ file: AttachedFile) {
        attachedFiles.removeAll { $0.id == file.id }
    }
}
