//
//  CoachDraft.swift
//  Simon
//
//  Created on 2026-01-19.
//

import Foundation

struct CoachDraft: Codable {
    var name: String = ""
    var promise: String = ""
    var style: CoachStyle = .direct
    var tone: Double = 0.5 // 0.0 = gentle, 1.0 = intense
    var framework: CoachFramework = .focusSprint
    var guardrails: Set<Guardrail> = []
    
    enum CoachStyle: String, Codable, CaseIterable {
        case direct = "direct"
        case warm = "warm"
        case socratic = "socratic"
        
        var displayName: String {
            switch self {
            case .direct: return "Direct"
            case .warm: return "Warm"
            case .socratic: return "Socratic"
            }
        }
        
        var description: String {
            switch self {
            case .direct: return "Clear, actionable guidance"
            case .warm: return "Supportive and encouraging"
            case .socratic: return "Questions that guide discovery"
            }
        }
    }
    
    enum CoachFramework: String, Codable, CaseIterable {
        case focusSprint = "focus_sprint"
        case weeklyReview = "weekly_review"
        case decisionMatrix = "decision_matrix"
        case habitSystem = "habit_system"
        case creativeOutput = "creative_output"
        
        var displayName: String {
            switch self {
            case .focusSprint: return "Focus Sprint"
            case .weeklyReview: return "Weekly Review"
            case .decisionMatrix: return "Decision Matrix"
            case .habitSystem: return "Habit System"
            case .creativeOutput: return "Creative Output"
            }
        }
        
        var description: String {
            switch self {
            case .focusSprint: return "Turn stuckness into 20-minute next steps"
            case .weeklyReview: return "Reflect, plan, and prioritize weekly"
            case .decisionMatrix: return "Make clear decisions with frameworks"
            case .habitSystem: return "Build sustainable routines"
            case .creativeOutput: return "Ship creative work consistently"
            }
        }
    }
    
    enum Guardrail: String, Codable, CaseIterable {
        case askQuestionFirst = "ask_question_first"
        case threeStepAnswers = "three_step_answers"
        case offerSystem = "offer_system"
        case respectValues = "respect_values"
        
        var displayName: String {
            switch self {
            case .askQuestionFirst: return "Ask 1 question first"
            case .threeStepAnswers: return "3-step answers"
            case .offerSystem: return "Offer a system"
            case .respectValues: return "Respect my values"
            }
        }
    }
    
    func toBlueprint() -> [String: Any] {
        return [
            "version": "1.0",
            "style": [
                "tone": style.rawValue,
                "intensity": tone
            ],
            "rules": [
                "alwaysAskOneClarifyingQuestionFirst": guardrails.contains(.askQuestionFirst),
                "defaultAnswerShape": guardrails.contains(.threeStepAnswers) ? "three_steps" : "flexible",
                "offerSystemWhenUseful": guardrails.contains(.offerSystem),
                "respectContextVault": guardrails.contains(.respectValues)
            ],
            "framework": [
                "name": framework.rawValue
            ],
            "safety": [
                "noMedicalLegalClaims": true,
                "encourageProfessionalHelpWhenNeeded": true
            ]
        ]
    }
}
