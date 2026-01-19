//
//  MomentViewModel.swift
//  Simon
//
//  Created on Day 12-14: Moment + Router Agent
//

import Foundation
import Combine

struct MomentTemplate: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let prompt: String
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
    
    private let apiClient: SimonAPI
    private let purchases: PurchasesService
    
    var isPro: Bool {
        purchases.isPro
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
}
