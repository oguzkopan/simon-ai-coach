//
//  CoachBuilderViewModel.swift
//  Simon
//
//  Created on 2026-01-19.
//

import Foundation
import Combine

@MainActor
final class CoachBuilderViewModel: ObservableObject {
    @Published var draft: CoachDraft
    @Published var currentStep: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPaywall = false
    
    private let apiClient: SimonAPIClient
    private let isPro: Bool
    private let onComplete: (Coach) -> Void
    
    let totalSteps = 4
    
    init(
        draft: CoachDraft? = nil,
        apiClient: SimonAPIClient,
        isPro: Bool,
        onComplete: @escaping (Coach) -> Void
    ) {
        self.apiClient = apiClient
        self.isPro = isPro
        self.onComplete = onComplete
        self.draft = draft ?? CoachDraft()
    }
    
    var canProceed: Bool {
        switch currentStep {
        case 0: return !draft.name.isEmpty && !draft.promise.isEmpty
        case 1: return true // Style always has default
        case 2: return true // Framework always has default
        case 3: return true // Guardrails optional
        default: return false
        }
    }
    
    var isLastStep: Bool {
        currentStep == totalSteps - 1
    }
    
    func nextStep() {
        guard canProceed else { return }
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    func save() async {
        guard canProceed else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let coach = try await apiClient.createCoach(draft: draft)
            isLoading = false
            onComplete(coach)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    func publish() async {
        guard isPro else {
            showPaywall = true
            return
        }
        
        guard canProceed else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // First create the coach
            let coach = try await apiClient.createCoach(draft: draft)
            
            // Then publish it
            let publishedCoach = try await apiClient.publishCoach(coachId: coach.id)
            
            isLoading = false
            onComplete(publishedCoach)
        } catch APIError.proRequired {
            isLoading = false
            showPaywall = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleGuardrail(_ guardrail: CoachDraft.Guardrail) {
        if draft.guardrails.contains(guardrail) {
            draft.guardrails.remove(guardrail)
        } else {
            draft.guardrails.insert(guardrail)
        }
    }
}
