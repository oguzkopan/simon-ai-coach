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
    
    let sessionID: String
    let coachName: String
    
    private let apiClient: SimonAPI
    private var streamingTask: Task<Void, Never>?
    
    init(sessionID: String, coachName: String, apiClient: SimonAPI) {
        self.sessionID = sessionID
        self.coachName = coachName
        self.apiClient = apiClient
    }
    
    func loadMessages() async {
        do {
            let detail = try await apiClient.getSession(id: sessionID)
            messages = detail.messages
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
                let stream = apiClient.streamChat(sessionID: sessionID, userText: userText)
                
                for try await delta in stream {
                    if Task.isCancelled { break }
                    
                    switch delta.kind {
                    case "token":
                        if let token = delta.token {
                            assistantText += token
                            
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
                        }
                    case "final":
                        break
                    case "error":
                        errorMessage = delta.error ?? "Unknown error"
                    default:
                        break
                    }
                }
            } catch {
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
    
    deinit {
        streamingTask?.cancel()
    }
}
