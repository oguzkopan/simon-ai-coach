//
//  MomentViewModel.swift
//  Simon
//

import Foundation
import Combine
import AVFoundation
import PhotosUI
import SwiftUI
import FirebaseStorage
import FirebaseAuth

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
    @Published var navigateToChat: Bool = false {
        didSet {
            print("🔄 navigateToChat changed: \(oldValue) → \(navigateToChat)")
            if navigateToChat {
                print("✅ Navigation should trigger now")
                print("   - sessionId: \(createdSessionId ?? "nil")")
                print("   - coachName: \(createdCoachName ?? "nil")")
                print("   - pendingVoiceData: \(pendingVoiceData?.count ?? 0) bytes")
            }
        }
    }
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
    @Published var selectedImage: UIImage? {
        didSet { if let image = selectedImage { handlePickedImage(image) } }
    }
    @Published var selectedDocumentURL: URL? {
        didSet { if let url = selectedDocumentURL { handleDocumentSelection(url) } }
    }
    @Published var inputMode: InputMode = .voice // Toggle between text and voice (voice is default)
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.3, count: 40) // For waveform visualization
    @Published var voiceOverEnabled: Bool = true // Voice-over preference
    @Published var pendingVoiceData: Data? // Store voice data to send after navigation
    
    // Voice recording manager (same as ChatView)
    @Published var voiceRecordingManager = VoiceRecordingManager()
    
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
    private var recordingObserverTimer: Timer?
    
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
    
    func sendVoiceMessage() async {
        guard let recordedAudio = voiceRecordingManager.recordedAudio else {
            errorMessage = "No audio recording available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Use the PCM16 data from the recording manager
            let audioData = recordedAudio.data
            
            print("🎤 Sending voice message - audio size: \(audioData.count) bytes, duration: \(recordedAudio.duration)s")
            
            // Create session WITHOUT saving a message
            // The voice message will be saved when we stream it
            let response = try await apiClient.startMoment(prompt: "", attachments: nil) // Empty prompt for voice-only
            
            print("✅ Session created: \(response.sessionId)")
            
            // Store session info for navigation
            createdSessionId = response.sessionId
            createdCoachName = response.coachName
            createdInitialPrompt = nil // Will send voice after navigation
            
            // Store audio data for sending after navigation
            pendingVoiceData = audioData
            
            print("🎤 Pending voice data stored: \(audioData.count) bytes")
            print("🎤 Setting navigateToChat = true")
            
            // Navigate to chat - the chat will handle sending the voice message
            // DON'T reset isLoading or delete audio yet - let navigation complete first
            navigateToChat = true
            
            print("✅ Navigation triggered, waiting for view to appear")
            
        } catch {
            print("❌ Voice message send error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func startMoment(prompt: String) async {
        // No paywall restrictions - everyone can use moments
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Upload attachments if any
            var uploadedAttachments: [Attachment]? = nil
            if !attachedFiles.isEmpty {
                uploadedAttachments = try await uploadAttachments()
            }
            
            // Call backend to create session immediately
            let response = try await apiClient.startMoment(prompt: prompt, attachments: uploadedAttachments)
            
            // Navigate to chat immediately
            // The chat will show "Finding the best coach for you..." while streaming
            createdSessionId = response.sessionId
            createdCoachName = response.coachName
            createdInitialPrompt = prompt // Pass the prompt to trigger streaming
            navigateToChat = true
            
            // Reset loading state after navigation is triggered
            isLoading = false
            
            // Reset form
            freeformInput = ""
            selectedTemplate = nil
            attachedFiles = [] // Clear attachments
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Attachment Upload
    
    private func uploadAttachments() async throws -> [Attachment] {
        guard let uid = authManager.currentUser?.uid else {
            throw NSError(domain: "MomentViewModel", code: 401,
                         userInfo: [NSLocalizedDescriptionKey: "You must be signed in to upload files"])
        }
        
        return try await withThrowingTaskGroup(of: Attachment.self) { group in
            for file in attachedFiles {
                group.addTask {
                    return try await self.uploadSingleAttachment(file, uid: uid)
                }
            }
            
            var results: [Attachment] = []
            for try await attachment in group {
                results.append(attachment)
            }
            return results
        }
    }
    
    private func uploadSingleAttachment(_ file: AttachedFile, uid: String) async throws -> Attachment {
        let filename = file.name
        let sessionId = UUID().uuidString // Temporary session ID for upload path
        let path = "uploads/\(uid)/\(sessionId)/\(filename)"
        
        // Import Firebase Storage
        let storageRef = Storage.storage().reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = file.type == .image ? "image/jpeg" : "application/octet-stream"
        
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(file.data, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let url = url {
                        let attachment = Attachment(
                            type: file.type == .image ? "image" : "file",
                            storagePath: "gs://\(storageRef.bucket)/\(path)",
                            downloadURL: url.absoluteString,
                            mimeType: metadata?.contentType ?? "application/octet-stream"
                        )
                        continuation.resume(returning: attachment)
                    } else {
                        continuation.resume(throwing: NSError(domain: "MomentViewModel", code: 500,
                                                             userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                    }
                }
            }
        }
    }
    
    private func incrementMomentCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "moments_count_\(today.timeIntervalSince1970)"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }
    
    func createChatViewModel(sessionId: String, coachName: String, initialPrompt: String?) -> ChatViewModel {
        print("🎤 Creating ChatViewModel with voiceOverEnabled: \(voiceOverEnabled)")
        
        let chatVM = ChatViewModel(
            sessionID: sessionId,
            coachName: coachName,
            apiClient: apiClient,
            initialPrompt: initialPrompt,
            isNewSession: true, // This is a new session from a moment
            purchasesService: purchases,
            voiceOverEnabled: voiceOverEnabled // Pass voice-over preference during init (will override UserDefaults)
        )
        
        print("✅ ChatViewModel created with voiceOverEnabled: \(chatVM.voiceOverEnabled)")
        
        // If we have pending voice data, send it after chat loads
        // IMPORTANT: Don't modify @Published properties here - it causes infinite loop
        if let voiceData = pendingVoiceData {
            Task {
                // Wait a moment for chat to initialize
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Send the voice message
                await chatVM.sendVoiceMessageFromMoment(voiceData)
                
                print("✅ Voice data sent to chat")
            }
        }
        
        return chatVM
    }
    
    func cleanupAfterNavigation() {
        // Clean up state after navigation completes
        // DON'T reset navigateToChat here - let it stay true so navigation persists
        Task { @MainActor in
            // Small delay to ensure navigation is complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Only cleanup audio and pending data, keep navigation state
            pendingVoiceData = nil
            deleteRecordedAudio()
            
            print("🧹 MomentView audio cleaned up after navigation")
        }
    }
    
    func resetForNewMoment() {
        // Call this when user explicitly goes back to MomentView
        navigateToChat = false
        createdSessionId = nil
        createdCoachName = nil
        createdInitialPrompt = nil
        isLoading = false
        
        print("🔄 MomentView reset for new moment")
    }
    
    // MARK: - Voice Input
    
    func toggleInputMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            inputMode = inputMode == .text ? .voice : .text
        }
        
        // Stop recording if switching away from voice mode
        if inputMode == .text && isRecording {
            Task {
                await voiceRecordingManager.cancelRecording()
                isRecording = false
            }
        }
    }
    
    func startVoiceRecording() {
        Task {
            do {
                try await voiceRecordingManager.startRecording()
                isRecording = true
                
                // Start timer to update duration and levels
                startRecordingObserver()
                
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isRecording = false
            }
        }
    }
    
    private func startRecordingObserver() {
        // Invalidate any existing timer
        recordingObserverTimer?.invalidate()
        
        // Observe the recording manager's published properties
        recordingObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Check if still recording using the manager's property
                guard self.voiceRecordingManager.isRecording else {
                    self.recordingObserverTimer?.invalidate()
                    self.recordingObserverTimer = nil
                    return
                }
                
                // Update duration from manager
                self.recordingDuration = self.voiceRecordingManager.duration
                
                // Convert Float array to CGFloat for UI
                self.audioLevels = self.voiceRecordingManager.audioLevels.map { CGFloat($0) }
            }
        }
    }
    
    func stopVoiceRecording() {
        Task {
            do {
                // Stop the observer timer
                recordingObserverTimer?.invalidate()
                recordingObserverTimer = nil
                
                let recorded = try await voiceRecordingManager.stopRecording()
                isRecording = false
                
                print("✅ Recording stopped - duration: \(recorded.duration)s, data size: \(recorded.data.count) bytes")
                
                // Save the recording for playback
                recordedAudioURL = recorded.fileURL
                savedAudioDuration = recorded.duration
                hasRecordedAudio = true
                
                // Prepare audio player for playback
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playback, mode: .default)
                    try audioSession.setActive(true)
                    
                    audioPlayer = try AVAudioPlayer(contentsOf: recorded.fileURL)
                    audioPlayer?.delegate = self
                    audioPlayer?.prepareToPlay()
                    
                    print("✅ Audio player prepared for playback")
                } catch {
                    print("❌ Failed to prepare audio player: \(error)")
                    errorMessage = "Failed to prepare audio for playback"
                }
                
            } catch {
                print("❌ Failed to stop recording: \(error)")
                errorMessage = "Failed to save recording: \(error.localizedDescription)"
                isRecording = false
            }
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
        
        // Reset the voice recording manager
        voiceRecordingManager.reset()
        
        recordedAudioURL = nil
        audioPlayer = nil
        hasRecordedAudio = false
        savedAudioDuration = 0
        audioPlaybackPosition = 0
    }
    
    func cancelVoiceRecording() {
        Task {
            // Stop the observer timer
            recordingObserverTimer?.invalidate()
            recordingObserverTimer = nil
            
            await voiceRecordingManager.cancelRecording()
            isRecording = false
            recordingDuration = 0
            audioLevels = Array(repeating: 0.3, count: 40)
        }
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
    
    private func handlePickedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let file = AttachedFile(
            name: "image_\(Date().timeIntervalSince1970).jpg",
            type: .image,
            data: data
        )
        attachedFiles.append(file)
        selectedImage = nil
    }
    
    func handleDocumentSelection(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            let file = AttachedFile(
                name: url.lastPathComponent,
                type: .document,
                data: data
            )
            attachedFiles.append(file)
            selectedDocumentURL = nil
        } catch {
            errorMessage = "Failed to load document: \(error.localizedDescription)"
        }
    }
    
    func removeAttachment(_ file: AttachedFile) {
        attachedFiles.removeAll { $0.id == file.id }
    }
}
