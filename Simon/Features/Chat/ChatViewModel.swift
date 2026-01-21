import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var composerText = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?
    @Published var showAttachmentPicker = false
    @Published var showPinSheet = false
    @Published var selectedMessageForPin: Message?
    
    // New SSE event handling
    @Published var nextActionsCard: NextActionsCardPayload?
    @Published var planCard: PlanCardPayload?
    @Published var weeklyReviewCard: WeeklyReviewCardPayload?
    @Published var toolRequest: ToolRequestPayload?
    @Published var policyNotice: String?
    @Published var showToolConfirmation = false
    
    let sessionID: String
    let coachName: String
    
    private let apiClient: SimonAPI
    private let toolExecutor: ToolExecutor
    private var streamingTask: Task<Void, Never>?
    
    // Session details for tool execution context
    private var sessionUID: String?
    private var sessionCoachID: String?
    
    init(sessionID: String, coachName: String, apiClient: SimonAPI, toolExecutor: ToolExecutor? = nil) {
        self.sessionID = sessionID
        self.coachName = coachName
        self.apiClient = apiClient
        self.toolExecutor = toolExecutor ?? ToolExecutor(apiClient: apiClient)
    }
    
    func loadMessages() async {
        do {
            let detail = try await apiClient.getSession(id: sessionID)
            messages = detail.messages
            // Store session context for tool execution
            sessionUID = detail.session.uid
            sessionCoachID = detail.session.coachID
        } catch {
            errorMessage = error.localizedDescription
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
                            messages[index] = Message(
                                id: payload.messageId,
                                role: payload.role,
                                contentText: payload.text,
                                attachments: nil,
                                createdAt: Date()
                            )
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
                        showToolConfirmation = true
                        
                    case .toolStatus(let payload):
                        print("🔧 Tool status: \(payload.status)")
                        
                    case .policyNotice(let payload):
                        print("⚠️ Policy notice: \(payload.message)")
                        policyNotice = payload.message
                        
                    case .error(let payload):
                        print("❌ Error event: \(payload.message)")
                        errorMessage = payload.message
                        
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
        
        // Ensure we have session context
        guard let uid = sessionUID, let coachID = sessionCoachID else {
            errorMessage = "Missing session context for tool execution"
            return
        }
        
        do {
            try await toolExecutor.executeToolWithConfirmation(
                toolID: toolRequest.toolId,
                sessionID: sessionID,
                input: toolRequest.input,
                uid: uid,
                coachID: coachID,
                onConfirm: { true }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        showToolConfirmation = false
        self.toolRequest = nil
    }
    
    func declineToolExecution() {
        guard let toolRequest = toolRequest else { return }
        
        Task {
            do {
                // Request execution to get tool run ID
                let response = try await toolExecutor.requestExecution(
                    toolID: toolRequest.toolId,
                    sessionID: sessionID,
                    input: toolRequest.input
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
        
        showToolConfirmation = false
        self.toolRequest = nil
    }
    
    deinit {
        streamingTask?.cancel()
    }
}
