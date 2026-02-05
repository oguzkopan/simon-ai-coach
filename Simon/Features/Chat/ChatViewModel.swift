import Foundation
import SwiftUI
import Combine
import FirebaseStorage
import UIKit
import FirebaseAuth

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var composerText = ""
    @Published var isStreaming = false
    @Published var isLoadingMessages = false
    @Published var errorMessage: String?
    @Published var showAttachmentPicker = false
    @Published var showPinSheet = false
    @Published var selectedMessageForPin: Message?
    
    // Attachment Handling
    @Published var selectedImage: UIImage? {
        didSet { if let image = selectedImage { handlePickedImage(image) } }
    }
    @Published var selectedFileURL: URL? {
        didSet { if let url = selectedFileURL { handlePickedDocument(url) } }
    }
    
    struct LocalAttachment: Identifiable {
        let id = UUID()
        let type: String // "image" or "file"
        let data: Data
        let mimeType: String
        let fileExtension: String
        let previewImage: UIImage? // For UI
    }
    
    @Published var localAttachments: [LocalAttachment] = []
    @Published var isUploading = false
    @Published var shouldShowError = false // Control when to show error UI
    @Published var hasCompletedInitialLoad = false // Track if we've completed the first load
    
    // Voice recording
    @Published var isVoiceMode = false
    @Published var voiceRecordingManager = VoiceRecordingManager()
    
    // New SSE event handling
    @Published var nextActionsCard: NextActionsCardPayload?
    @Published var planCard: PlanCardPayload?
    @Published var weeklyReviewCard: WeeklyReviewCardPayload?
    @Published var toolRequest: ToolRequestPayload? // Shown inline, not as sheet
    @Published var policyNotice: String?
    
    // Tool request history with approval status
    struct ToolRequestHistory: Identifiable {
        let id: String
        let toolRequest: ToolRequestPayload
        var status: ToolApprovalStatus
        let timestamp: Date
        
        enum ToolApprovalStatus {
            case pending
            case approved
            case declined
        }
    }
    @Published var toolRequestHistory: [ToolRequestHistory] = []
    
    let sessionID: String
    let coachName: String
    let initialPrompt: String?
    let isNewSession: Bool // Flag to indicate if this is a newly created session
    
    private let apiClient: SimonAPI
    private let toolExecutor: ToolExecutor
    private var streamingTask: Task<Void, Never>?
    private var hasLoadedInitialPrompt = false
    private var hasLoadedMessages = false // Track if we've already loaded messages
    private var errorDisplayTask: Task<Void, Never>?
    
    // Session details for tool execution context
    private var sessionUID: String?
    var sessionCoachID: String? // Made public for analytics
    
    func removeAttachment(id: UUID) {
        localAttachments.removeAll { $0.id == id }
    }
    
    init(sessionID: String, coachName: String, apiClient: SimonAPI, toolExecutor: ToolExecutor? = nil, initialPrompt: String? = nil, isNewSession: Bool = false) {
        print("🟢 ChatViewModel init - sessionID: \(sessionID), coachName: \(coachName), isNewSession: \(isNewSession)")
        self.sessionID = sessionID
        self.coachName = coachName
        self.apiClient = apiClient
        self.toolExecutor = toolExecutor ?? ToolExecutor(apiClient: apiClient)
        self.initialPrompt = initialPrompt
        self.isNewSession = isNewSession
    }
    
    func loadMessages() async {
        // If this is a brand new session (just created), don't try to load messages
        // The session exists but has no messages yet - this is expected
        if isNewSession {
            print("🟢 Brand new session - skipping message load, waiting for user input")
            isLoadingMessages = false
            hasLoadedMessages = true
            hasCompletedInitialLoad = true
            
            // Load session details for context (uid, coachID) but don't fail if it doesn't work yet
            do {
                let detail = try await apiClient.getSession(id: sessionID)
                sessionUID = detail.session.uid
                sessionCoachID = detail.session.coachID
                print("✅ Session context loaded: uid=\(sessionUID ?? "nil"), coachID=\(sessionCoachID ?? "nil")")
            } catch {
                print("⚠️ Could not load session context yet (session may still be initializing): \(error)")
                // Don't show error - this is expected for brand new sessions
            }
            
            // If we have an initial prompt, send it automatically
            if let prompt = initialPrompt, !hasLoadedInitialPrompt {
                hasLoadedInitialPrompt = true
                await MainActor.run {
                    composerText = prompt
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        send()
                    }
                }
            }
            
            return
        }
        
        // Prevent multiple simultaneous loads
        guard !hasLoadedMessages else {
            print("⚠️ Messages already loaded, skipping")
            return
        }
        
        guard !isLoadingMessages else {
            print("⚠️ Already loading messages, skipping")
            return
        }
        
        print("🔵 Starting loadMessages for session: \(sessionID)")
        hasLoadedMessages = true
        isLoadingMessages = true
        errorMessage = nil
        shouldShowError = false
        
        do {
            print("📥 Loading messages for session: \(sessionID)")
            print("📥 API client: \(type(of: apiClient))")
            
            let detail = try await apiClient.getSession(id: sessionID)
            
            print("✅ Successfully received session detail")
            print("✅ Session ID: \(detail.session.id)")
            print("✅ Session UID: \(detail.session.uid)")
            print("✅ Messages count: \(detail.messages.count)")
            
            if !detail.messages.isEmpty {
                print("✅ First message: \(detail.messages[0].contentText.prefix(50))...")
            }
            
            messages = detail.messages
            // Store session context for tool execution
            sessionUID = detail.session.uid
            sessionCoachID = detail.session.coachID
            
            isLoadingMessages = false
            hasCompletedInitialLoad = true // Mark as successfully loaded
            
            print("✅ Load complete. Messages array has \(messages.count) items")
            
            // If we have an initial prompt and haven't sent it yet, send it now
            if let prompt = initialPrompt, !hasLoadedInitialPrompt, messages.isEmpty {
                hasLoadedInitialPrompt = true
                // Set the composer text and trigger send
                await MainActor.run {
                    composerText = prompt
                    // Small delay to ensure UI is ready
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        send()
                    }
                }
            }
        } catch let error as NSError {
            print("❌ Failed to load messages")
            print("❌ Error domain: \(error.domain)")
            print("❌ Error code: \(error.code)")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Error userInfo: \(error.userInfo)")
            
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("❌ Underlying error: \(underlyingError)")
            }
            
            isLoadingMessages = false
            hasLoadedMessages = false // Allow retry
            hasCompletedInitialLoad = false // Mark as failed
            
            // Check if it's a 404 (session not found) or 403 (access denied)
            let errorDesc = error.localizedDescription
            let errorCode = error.code
            
            print("❌ Analyzing error...")
            
            if errorCode == 401 || errorDesc.contains("401") || errorDesc.contains("Unauthorized") {
                print("❌ Detected: Unauthorized (401)")
                errorMessage = "Please sign in to view your sessions."
            } else if errorCode == 404 || errorDesc.contains("404") || errorDesc.contains("not found") {
                print("❌ Detected: Not Found (404)")
                errorMessage = "Session not found. It may have been deleted."
            } else if errorCode == 403 || errorDesc.contains("403") || errorDesc.contains("access denied") || errorDesc.contains("Forbidden") {
                print("❌ Detected: Forbidden (403)")
                errorMessage = "You don't have access to this session. Please sign in with the account that created it."
            } else if errorCode == -999 || errorDesc.contains("cancelled") {
                print("❌ Detected: Cancelled (-999)")
                // Don't show error for cancelled requests
                errorMessage = nil
            } else {
                print("❌ Detected: Generic error")
                errorMessage = "Failed to load messages. Please check your connection and try again."
            }
            
            print("❌ Final error message: \(errorMessage ?? "nil")")
            
            // Only show error UI after a brief delay to avoid flashing
            if errorMessage != nil {
                errorDisplayTask?.cancel()
                errorDisplayTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    if !Task.isCancelled {
                        print("❌ Showing error UI")
                        shouldShowError = true
                    }
                }
            }
            
            // Initialize with empty messages if loading fails
            messages = []
            
            // Still try to send initial prompt even if loading failed
            if let prompt = initialPrompt, !hasLoadedInitialPrompt {
                hasLoadedInitialPrompt = true
                await MainActor.run {
                    composerText = prompt
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        send()
                    }
                }
            }
        }
    }
    
    func send() {
        guard !composerText.isEmpty || !localAttachments.isEmpty else { return }
        
        let userText = composerText
        // Local references to process
        let attachmentsToProcess = localAttachments
        
        // Optimistically clear input
        composerText = ""
        localAttachments = []
        isVoiceMode = false
        
        // Clear previous cards
        nextActionsCard = nil
        planCard = nil
        weeklyReviewCard = nil
        toolRequest = nil
        policyNotice = nil
        
        // Start processing
        isStreaming = true // Indicate activity
        errorMessage = nil
        
        streamingTask = Task {
            // 1. Upload Attachments
            var uploadedAttachments: [Attachment] = []
            if !attachmentsToProcess.isEmpty {
                isUploading = true
                do {
                    uploadedAttachments = try await uploadAllAttachments(attachmentsToProcess)
                } catch {
                    // Restore state on failure
                    await MainActor.run {
                        self.errorMessage = "Failed to send: \(error.localizedDescription)"
                        self.composerText = userText
                        self.localAttachments = attachmentsToProcess
                        self.isUploading = false
                        self.isStreaming = false
                    }
                    return
                }
                isUploading = false
            }
            
            // 2. Add user message to UI
            // We use the same Task context so simple property access is safe, but explicit MainActor.run is better for updates
            await MainActor.run {
                
                // Log analytics
                AnalyticsManager.shared.logMessageSent(
                    coachID: sessionCoachID ?? "unknown",
                    messageLength: userText.count
                )
                
                let userMessage = Message(
                    id: UUID().uuidString,
                    role: "user",
                    contentText: userText,
                    attachments: uploadedAttachments,
                    createdAt: Date()
                )
                messages.append(userMessage)
            }
            
            // 3. Start Streaming
            await streamResponse(userText: userText, attachments: uploadedAttachments)
        }
    }
    
    private func streamResponse(userText: String, attachments: [Attachment]?) async {
        
        var assistantText = "" 
        let assistantID = UUID().uuidString
        
        // Add placeholder assistant message
        await MainActor.run {
            let placeholderMessage = Message(
                id: assistantID,
                role: "assistant",
                contentText: "",
                attachments: nil,
                createdAt: Date()
            )
            messages.append(placeholderMessage)
        }

        
        do {
            print("🚀 Starting chat stream for session: \(sessionID)")
            let stream = apiClient.streamChat(sessionID: sessionID, userText: userText, attachments: attachments)
            
            for try await event in stream {
                    if Task.isCancelled {
                        print("⚠️ Stream task cancelled")
                        break
                    }
                    
                    print("📨 Received event: \(event)")
                    
                    switch event {
                    case .streamOpen(let payload):
                        print("✅ Stream opened: \(payload.sessionId)")
                        
                    case .messageDelta(let payload):
                        print("📝 Message delta: \(payload.delta)")
                        // Update UI immediately (direct pass, no buffer)
                        await MainActor.run {
                            assistantText += payload.delta
                            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                                messages[index] = Message(
                                    id: assistantID,
                                    role: "assistant",
                                    contentText: assistantText,
                                    attachments: nil,
                                    createdAt: Date()
                                )
                            }
                        }
                        
                    case .messageFinal(let payload):
                        print("✅ Message final: \(payload.text.prefix(50))...")
                        let finalID = payload.messageId // Capture for local scope

                        // Ensure we show the final text exactly as received
                        await MainActor.run {
                            assistantText = payload.text // Sync buffer
                            
                            // Also handle the edge case where function calls produce empty text
                            if payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // If function call only, remove the placeholder
                                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                                    messages.remove(at: index)
                                }
                            } else {
                                // Final sync with real ID
                                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                                    messages[index] = Message(
                                        id: finalID,
                                        role: "assistant",
                                        contentText: assistantText,
                                        attachments: nil,
                                        createdAt: Date()
                                    )
                                }
                            }
                        }
                        
                    case .cardNextActions(let payload):
                        print("🎴 Next actions card received")
                        await MainActor.run { nextActionsCard = payload }
                        
                    case .cardPlan(let payload):
                        print("🎴 Plan card received")
                        await MainActor.run { planCard = payload }
                        
                    case .cardWeeklyReview(let payload):
                        print("🎴 Weekly review card received")
                        await MainActor.run { weeklyReviewCard = payload }
                        
                    case .toolRequest(let payload):
                        print("🔧 Tool request: \(payload.tool)")
                        await MainActor.run {
                            toolRequest = payload
                            // Add to history as pending
                            let historyItem = ToolRequestHistory(
                                id: UUID().uuidString,
                                toolRequest: payload,
                                status: .pending,
                                timestamp: Date()
                            )
                            toolRequestHistory.append(historyItem)
                        }
                        
                    case .toolStatus(let payload):
                        print("🔧 Tool status: \(payload.status)")
                        
                    case .policyNotice(let payload):
                        print("⚠️ Policy notice: \(payload.message)")
                        await MainActor.run { policyNotice = payload.message }
                        
                    case .error(let payload):
                        print("❌ Error event: \(payload.message)")
                        await MainActor.run {
                            if payload.message.contains("quota") || payload.message.contains("429") || payload.message.contains("RESOURCE_EXHAUSTED") {
                                errorMessage = "⏳ API rate limit reached. Please wait a moment and try again."
                            } else {
                                errorMessage = payload.message
                            }
                        }
                        
                    case .streamDone(let payload):
                        print("✅ Stream done: \(payload.status)")
                        
                    case .unknown(let type, let data):
                        print("❓ Unknown event type: \(type), data: \(data)")
                    }
                }
                
                print("🏁 Stream loop completed")
                
                // Final cleanup
                await MainActor.run {
                    isStreaming = false
                }
            } catch {
            print("❌ Stream error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                // Remove placeholder message on error
                messages.removeAll { $0.id == assistantID }
                isStreaming = false
            }
        }
    }
    
    func stopStreaming() {
        streamingTask?.cancel()
        isStreaming = false
    }
    
    // MARK: - Pin as System
    
    func pinAsSystem(_ message: Message) {
        selectedMessageForPin = message
        showPinSheet = true
    }
    
    func createSystem(title: String, checklist: [String], schedule: String, metrics: [String]) async {
        do {
            let system = System(
                id: UUID().uuidString,
                uid: "", // Will be set by backend
                title: title,
                checklist: checklist,
                scheduleSuggestion: schedule,
                metrics: metrics,
                sourceSessionID: sessionID,
                createdAt: Date()
            )
            
            _ = try await apiClient.createSystem(system: system)
            showPinSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Tool Execution
    
    func approveToolExecution() async {
        guard let toolRequest = toolRequest else { return }
        
        // Ensure we have session context - if not, try to reload it
        if sessionUID == nil || sessionCoachID == nil {
            print("⚠️ Missing session context, attempting to reload...")
            do {
                let detail = try await apiClient.getSession(id: sessionID)
                sessionUID = detail.session.uid
                sessionCoachID = detail.session.coachID
                print("✅ Session context reloaded: uid=\(sessionUID ?? "nil"), coachID=\(sessionCoachID ?? "nil")")
            } catch {
                print("❌ Failed to reload session context: \(error)")
                errorMessage = "Failed to load session context. Please try again."
                // Update history status to declined (failed)
                if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                    toolRequestHistory[index].status = .declined
                }
                self.toolRequest = nil
                return
            }
        }
        
        guard let uid = sessionUID, let coachID = sessionCoachID else {
            errorMessage = "Missing session context for tool execution"
            // Update history status to declined (failed)
            if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                toolRequestHistory[index].status = .declined
            }
            self.toolRequest = nil
            return
        }
        
        // Convert SSEAnyCodable to Any
        let input = toolRequest.input.mapValues { $0.value }
        
        print("🔧 Executing tool: \(toolRequest.toolId)")
        print("🔧 Input: \(input)")
        print("🔧 UID: \(uid)")
        print("🔧 CoachID: \(coachID)")
        
        do {
            try await toolExecutor.executeToolWithConfirmation(
                toolID: toolRequest.toolId,
                sessionID: sessionID,
                input: input,
                uid: uid,
                coachID: coachID,
                onConfirm: { true }
            )
            print("✅ Tool execution completed successfully")
            
            // Update history status to approved
            if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                toolRequestHistory[index].status = .approved
            }
        } catch {
            print("❌ Tool execution failed: \(error)")
            errorMessage = error.localizedDescription
            
            // Update history status to declined (failed)
            if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                toolRequestHistory[index].status = .declined
            }
        }
        
        // Clear the current tool request (but keep in history)
        self.toolRequest = nil
    }
    
    func declineToolExecution() {
        guard let toolRequest = toolRequest else { return }
        
        // Convert SSEAnyCodable to Any
        let input = toolRequest.input.mapValues { $0.value }
        
        Task {
            do {
                // Request execution to get tool run ID
                let response = try await toolExecutor.requestExecution(
                    toolID: toolRequest.toolId,
                    sessionID: sessionID,
                    input: input
                )
                
                // Report declined
                try await toolExecutor.reportResult(
                    toolRunID: response.toolRunID,
                    executionToken: response.executionToken ?? "",
                    status: "declined"
                )
                
                // Update history status to declined
                if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                    toolRequestHistory[index].status = .declined
                }
            } catch {
                errorMessage = error.localizedDescription
                
                // Still update history status to declined
                if let index = toolRequestHistory.firstIndex(where: { $0.status == .pending }) {
                    toolRequestHistory[index].status = .declined
                }
            }
        }
        
        // Clear the current tool request (but keep in history)
        self.toolRequest = nil
    }
    
    // MARK: - Voice Recording
    
    func sendVoiceMessage(_ audio: RecordedAudio) {
        // Clear previous cards
        nextActionsCard = nil
        planCard = nil
        weeklyReviewCard = nil
        toolRequest = nil
        policyNotice = nil
        
        // Reset voice mode and manager
        isVoiceMode = false
        voiceRecordingManager.reset()
        
        // Start streaming
        isStreaming = true
        errorMessage = nil
        
        streamingTask = Task {
            // Add user message to UI (voice indicator) - will be replaced when we reload
            await MainActor.run {
                AnalyticsManager.shared.logMessageSent(
                    coachID: sessionCoachID ?? "unknown",
                    messageLength: 0 // Voice message
                )
                
                let userMessage = Message(
                    id: UUID().uuidString,
                    role: "user",
                    contentText: "🎤 Voice message",
                    attachments: nil,
                    createdAt: Date()
                )
                messages.append(userMessage)
            }
            
            // Stream voice response
            await streamVoiceResponse(audioData: audio.data)
        }
    }
    
    private func streamVoiceResponse(audioData: Data) async {
        var assistantText = ""
        let assistantID = UUID().uuidString
        
        // Add placeholder assistant message
        await MainActor.run {
            let placeholderMessage = Message(
                id: assistantID,
                role: "assistant",
                contentText: "",
                attachments: nil,
                createdAt: Date()
            )
            messages.append(placeholderMessage)
        }
        
        do {
            print("🚀 Starting voice chat stream for session: \(sessionID)")
            let stream = apiClient.streamVoiceChat(
                sessionID: sessionID,
                audioData: audioData,
                text: nil,
                attachments: nil
            )
            
            // Reload messages after stream completes to get the saved messages with attachments
            // Don't reload during streaming - wait until done
            
            for try await event in stream {
                if Task.isCancelled {
                    print("⚠️ Stream task cancelled")
                    break
                }
                
                print("📨 Received voice event: \(event)")
                
                switch event {
                case .streamOpen(let payload):
                    print("✅ Voice stream opened: \(payload.sessionId)")
                    
                case .messageDelta(let payload):
                    print("📝 Voice message delta: \(payload.delta)")
                    await MainActor.run {
                        assistantText += payload.delta
                        if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[index] = Message(
                                id: assistantID,
                                role: "assistant",
                                contentText: assistantText,
                                attachments: nil,
                                createdAt: Date()
                            )
                        }
                    }
                    
                case .messageFinal(let payload):
                    print("✅ Voice message final: \(payload.text.prefix(50))...")
                    let finalID = payload.messageId
                    
                    await MainActor.run {
                        assistantText = payload.text
                        
                        if payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                                messages.remove(at: index)
                            }
                        } else {
                            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                                messages[index] = Message(
                                    id: finalID,
                                    role: "assistant",
                                    contentText: assistantText,
                                    attachments: nil,
                                    createdAt: Date()
                                )
                            }
                        }
                    }
                    
                case .error(let payload):
                    print("❌ Voice error event: \(payload.message)")
                    await MainActor.run {
                        if payload.message.contains("quota") || payload.message.contains("429") || payload.message.contains("RESOURCE_EXHAUSTED") {
                            errorMessage = "⏳ API rate limit reached. Please wait a moment and try again."
                        } else {
                            errorMessage = payload.message
                        }
                    }
                    
                case .streamDone(let payload):
                    print("✅ Voice stream done: \(payload.status)")
                    
                default:
                    // Handle other events (cards, tools, etc.)
                    break
                }
            }
            
            print("🏁 Voice stream loop completed")
            
            await MainActor.run {
                isStreaming = false
                isVoiceMode = false
            }
            
            // Wait a moment for the backend to finish saving the message with attachments
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Reload messages to get the saved messages with audio attachments
            // This will replace the placeholder messages with the real ones from the server
            hasLoadedMessages = false // Allow reload
            await loadMessages()
        } catch {
            print("❌ Voice stream error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                messages.removeAll { $0.id == assistantID }
                isStreaming = false
                isVoiceMode = false
            }
        }
    }
    
    func startVoiceRecording() {
        isVoiceMode = true
        Task {
            do {
                try await voiceRecordingManager.startRecording()
            } catch {
                errorMessage = error.localizedDescription
                isVoiceMode = false
            }
        }
    }
    
    func cancelVoiceRecording() {
        Task {
            await voiceRecordingManager.cancelRecording()
            isVoiceMode = false
        }
    }
    
    deinit {
        streamingTask?.cancel()
        errorDisplayTask?.cancel()
    }
    
    // MARK: - Attachment Upload
    
    // MARK: - Attachment Handling
    
    private func handlePickedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let attachment = LocalAttachment(
            type: "image",
            data: data,
            mimeType: "image/jpeg",
            fileExtension: "jpg",
            previewImage: image
        )
        localAttachments.append(attachment)
        selectedImage = nil
    }
    
    private func handlePickedDocument(_ url: URL) {
        // Securely access the file
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension
            let mimeType = ext == "pdf" ? "application/pdf" : "application/octet-stream"
            // For generic files, we might want a generic icon.
            // Since we can't easily generate a PDF thumbnail synchronously, utilize a system icon in UI based on type.
            // Here `previewImage` is just nil or a placeholder? Let's keep it nil and handle in UI.
            
            let attachment = LocalAttachment(
                type: "file",
                data: data,
                mimeType: mimeType,
                fileExtension: ext,
                previewImage: nil
            )
            localAttachments.append(attachment)
            selectedFileURL = nil
        } catch {
            print("❌ Failed to read file data: \(error.localizedDescription)")
            errorMessage = "Failed to access the selected file"
        }
    }
    
    private func uploadAllAttachments(_ attachments: [LocalAttachment]) async throws -> [Attachment] {
        guard !attachments.isEmpty else { return [] }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ChatViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to upload files"])
        }
        
        return try await withThrowingTaskGroup(of: Attachment.self) { group in
            for localAtt in attachments {
                group.addTask {
                    return try await self.uploadSingleAttachment(localAtt, uid: uid)
                }
            }
            
            var results: [Attachment] = []
            for try await attachment in group {
                results.append(attachment)
            }
            return results
        }
    }
    
    private func uploadSingleAttachment(_ attachment: LocalAttachment, uid: String) async throws -> Attachment {
        let filename = "\(UUID().uuidString).\(attachment.fileExtension)"
        let path = "uploads/\(uid)/\(sessionID)/\(filename)"
        let storageRef = Storage.storage().reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = attachment.mimeType
        
        // We wrap the callback-based putData in a continuation
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(attachment.data, metadata: metadata) { metadata, error in
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
                        let uploadedAtt = Attachment(
                            type: attachment.type,
                            storagePath: "gs://\(storageRef.bucket)/\(path)",
                            downloadURL: url.absoluteString,
                            mimeType: attachment.mimeType
                        )
                        continuation.resume(returning: uploadedAtt)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ChatViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                    }
                }
            }
        }
    }
}
