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

@MainActor
final class MomentViewModel: ObservableObject {
    @Published var freeformInput: String = ""
    @Published var selectedTemplate: MomentTemplate?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showPaywall: Bool = false
    @Published var navigateToChat: Bool = false
    @Published var createdSessionId: String?
    @Published var createdCoachName: String?
    @Published var remainingMoments: Int = 3
    @Published var isRecording: Bool = false
    @Published var routines: [System] = []
    @Published var selectedRoutine: System?
    @Published var showImagePicker: Bool = false
    @Published var showDocumentPicker: Bool = false
    @Published var attachedFiles: [AttachedFile] = []
    @Published var selectedPhotoItem: PhotosPickerItem?
    
    private let apiClient: SimonAPI
    private let purchases: PurchasesService
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    
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
        // Check Pro status or remaining moments
        if !isPro && remainingMoments <= 0 {
            showPaywall = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Call backend to start moment
            let response = try await apiClient.startMoment(prompt: prompt)
            
            // Increment moment count if not Pro
            if !isPro {
                incrementMomentCount()
                await loadRemainingMoments()
            }
            
            // Navigate to chat with created session
            createdSessionId = response.sessionId
            createdCoachName = response.coachName
            navigateToChat = true
            
            // Reset form
            freeformInput = ""
            selectedTemplate = nil
            
        } catch let error as APIError {
            if case .proRequired = error {
                showPaywall = true
            } else {
                errorMessage = error.localizedDescription
            }
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
    
    func createChatViewModel(sessionId: String, coachName: String) -> ChatViewModel {
        return ChatViewModel(
            sessionID: sessionId,
            coachName: coachName,
            apiClient: apiClient
        )
    }
    
    // MARK: - Voice Input
    
    func toggleVoiceInput() {
        if isRecording {
            stopVoiceRecording()
        } else {
            startVoiceRecording()
        }
    }
    
    private func startVoiceRecording() {
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
                audioRecorder?.record()
                
                isRecording = true
                
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isRecording = false
            }
        }
    }
    
    private func stopVoiceRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        guard let recordingURL = audioRecorder?.url else {
            return
        }
        
        // Transcribe audio
        Task {
            await transcribeAudio(url: recordingURL)
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
