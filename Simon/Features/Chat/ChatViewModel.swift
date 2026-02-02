import Foundation
import SwiftUI
import Combine

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
    @Published var shouldShowError = false // Control when to show error UI
    @Published var hasCompletedInitialLoad = false // Track if we've completed the first load
    
    // New SSE event handling
    @Published var nextActionsCard: NextActionsCardPayload?
    @Published var planCard: PlanCardPayload?
    @Published var weeklyReviewCard: WeeklyReviewCardPayload?
    @Published var toolRequest: ToolRequestPayload? // Shown inline, not as sheet
    @Published var policyNotice: String?
    
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
    private var sessionCoachID: String?
    
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
        guard !composerText.isEmpty else { return }
        
        let userText = composerText
        composerText = ""
        
        // Add user message immediately
        let userMessage = Message(
            id: UUID().uuidString,
            role: "user",
            contentText: userText,
            attachments: nil,
            createdAt: Date()
        )
        messages.append(userMessage)
        
        // Clear previous cards
        nextActionsCard = nil
        planCard = nil
        weeklyReviewCard = nil
        toolRequest = nil
        policyNotice = nil
        
        // Start streaming
        isStreaming = true
        errorMessage = nil
        
        streamingTask = Task {
            var assistantText = ""
            let assistantID = UUID().uuidString
            
            // Add placeholder assistant message
            let placeholderMessage = Message(
                id: assistantID,
                role: "assistant",
                contentText: "",
                attachments: nil,
                createdAt: Date()
            )
            messages.append(placeholderMessage)
            
            do {
                print("🚀 Starting chat stream for session: \(sessionID)")
                let stream = apiClient.streamChat(sessionID: sessionID, userText: userText)
                
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
                        assistantText += payload.delta
                        
                        // Update the last message
                        if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[index] = Message(
                                id: assistantID,
                                role: "assistant",
                                contentText: assistantText,
                                attachments: nil,
                                createdAt: Date()
                            )
                        }
                        
                    case .messageFinal(let payload):
                        print("✅ Message final: \(payload.text.prefix(50))...")
                        // Update with final text
                        if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                            // Only add message if it has text content
                            // When function calling happens without text, we skip the message
                            if !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                messages[index] = Message(
                                    id: payload.messageId,
                                    role: payload.role,
                                    contentText: payload.text,
                                    attachments: nil,
                                    createdAt: Date()
                                )
                            } else {
                                // Remove placeholder if message is empty (function call only)
                                messages.remove(at: index)
                                print("🗑️ Removed empty assistant message (function call only)")
                            }
                        }
                        
                    case .cardNextActions(let payload):
                        print("🎴 Next actions card received")
                        nextActionsCard = payload
                        
                    case .cardPlan(let payload):
                        print("🎴 Plan card received")
                        planCard = payload
                        
                    case .cardWeeklyReview(let payload):
                        print("🎴 Weekly review card received")
                        weeklyReviewCard = payload
                        
                    case .toolRequest(let payload):
                        print("🔧 Tool request: \(payload.tool)")
                        toolRequest = payload
                        // No longer showing sheet, it's inline in the chat
                        
                    case .toolStatus(let payload):
                        print("🔧 Tool status: \(payload.status)")
                        
                    case .policyNotice(let payload):
                        print("⚠️ Policy notice: \(payload.message)")
                        policyNotice = payload.message
                        
                    case .error(let payload):
                        print("❌ Error event: \(payload.message)")
                        // Check if it's a quota error
                        if payload.message.contains("quota") || payload.message.contains("429") || payload.message.contains("RESOURCE_EXHAUSTED") {
                            errorMessage = "⏳ API rate limit reached. Please wait a moment and try again."
                        } else {
                            errorMessage = payload.message
                        }
                        
                    case .streamDone(let payload):
                        print("✅ Stream done: \(payload.status)")
                        
                    case .unknown(let type, let data):
                        print("❓ Unknown event type: \(type), data: \(data)")
                    }
                }
                
                print("🏁 Stream loop completed")
            } catch {
                print("❌ Stream error: \(error)")
                errorMessage = error.localizedDescription
                // Remove placeholder message on error
                messages.removeAll { $0.id == assistantID }
            }
            
            isStreaming = false
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
                self.toolRequest = nil
                return
            }
        }
        
        guard let uid = sessionUID, let coachID = sessionCoachID else {
            errorMessage = "Missing session context for tool execution"
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
        } catch {
            print("❌ Tool execution failed: \(error)")
            errorMessage = error.localizedDescription
        }
        
        // Clear the tool request to hide the approval card
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
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        // Clear the tool request to hide the approval card
        self.toolRequest = nil
    }
    
    deinit {
        streamingTask?.cancel()
        errorDisplayTask?.cancel()
    }
}
