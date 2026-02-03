import Foundation
import SwiftUI
import Combine

@MainActor
final class CoachBuilderViewModel: ObservableObject {
    // Basic Info
    @Published var title = ""
    @Published var promise = ""
    
    // Avatar
    @Published var avatarPrompt = ""
    @Published var avatarImage: UIImage?
    @Published var avatarImageData: Data?
    @Published var isGeneratingAvatar = false
    
    // Specialty & Style
    @Published var selectedSpecialty: CoachSpecialty = .focus
    @Published var selectedStyle: CoachingStyle = .direct
    
    // Advanced
    @Published var tone: Double = 0.5
    @Published var customSystemPrompt = ""
    @Published var showAdvanced = false
    
    // State
    @Published var isCreating = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient: SimonAPI
    private let onCoachCreated: (Coach) -> Void
    
    var canCreate: Bool {
        !title.isEmpty && !promise.isEmpty && avatarImage != nil
    }
    
    var toneLabel: String {
        if tone < 0.3 {
            return "Gentle"
        } else if tone < 0.7 {
            return "Balanced"
        } else {
            return "Intense"
        }
    }
    
    init(apiClient: SimonAPI, onCoachCreated: @escaping (Coach) -> Void) {
        self.apiClient = apiClient
        self.onCoachCreated = onCoachCreated
    }
    
    func generateAvatar() {
        guard !avatarPrompt.isEmpty else { return }
        
        isGeneratingAvatar = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.generateCoachAvatar(
                    prompt: avatarPrompt,
                    specialty: selectedSpecialty.rawValue,
                    style: selectedStyle.rawValue
                )
                
                // Decode base64 image
                if let imageData = Data(base64Encoded: response.imageData),
                   let image = UIImage(data: imageData) {
                    avatarImage = image
                    avatarImageData = imageData
                    HapticManager.shared.success()
                } else {
                    throw NSError(domain: "CoachBuilder", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to decode avatar image"
                    ])
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.shared.error()
            }
            
            isGeneratingAvatar = false
        }
    }
    
    func createCoach() {
        guard canCreate else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Build CoachSpec
                let coachSpec = buildCoachSpec()
                
                // Create coach
                let coach = try await apiClient.createCoach(
                    title: title,
                    promise: promise,
                    tags: [selectedSpecialty.rawValue],
                    coachSpec: coachSpec,
                    avatarData: avatarImageData
                )
                
                HapticManager.shared.success()
                onCoachCreated(coach)
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.shared.error()
            }
            
            isCreating = false
        }
    }
    
    private func buildCoachSpec() -> CoachSpec {
        let systemPrompt = buildSystemPrompt()
        
        return CoachSpec(
            version: "1.0",
            identity: Identity(
                name: title,
                tagline: promise,
                niche: selectedSpecialty.rawValue,
                audience: ["professionals", "individuals"],
                problemStatements: [promise],
                outcomes: ["Achieve clarity", "Take action", "Build momentum"],
                languages: ["en"],
                persona: Persona(
                    archetype: selectedStyle.rawValue,
                    voice: systemPrompt,
                    boundaries: ["No medical advice", "No legal advice", "No financial advice"]
                ),
                samplePrompts: generateSamplePrompts()
            ),
            style: Style(
                tone: selectedStyle.rawValue,
                verbosity: tone < 0.3 ? "concise" : (tone > 0.7 ? "detailed" : "balanced"),
                formatting: Formatting(
                    maxBullets: 5,
                    maxSentencesPerParagraph: 3,
                    alwaysEndWith: ["What's your next step?"],
                    useEmoji: "sparingly",
                    allowedMarkdown: ["bold", "italic", "lists"]
                ),
                interactionRules: InteractionRules(
                    askOneQuestionAtATime: true,
                    confirmBeforeScheduling: true,
                    avoidMotivationalFluff: selectedStyle == .direct,
                    reflectUserLanguage: true
                )
            ),
            methods: Methods(
                frameworks: nil,
                defaultProtocols: DefaultProtocols(
                    quickNudge: Protocol(template: ["Clarify", "Suggest", "Confirm"], phases: nil),
                    deepSession: Protocol(template: nil, phases: ["Explore", "Plan", "Commit"])
                )
            ),
            policies: Policies(
                refusals: Refusals(
                    medical: true,
                    legal: true,
                    financialAdvice: "redirect_to_professional",
                    selfHarm: "immediate_resources"
                ),
                privacy: Privacy(
                    storeSensitiveMemory: false,
                    redactPatterns: ["ssn", "credit_card"],
                    userControls: ["view", "delete", "export"]
                ),
                safety: Safety(
                    noManipulation: true,
                    noGuilt: true,
                    noShaming: true
                )
            ),
            toolsAllowed: ToolsAllowed(
                clientTools: ["calendar", "reminders"],
                serverTools: ["create_plan", "schedule_checkin"],
                requiresUserConfirmation: ["schedule_checkin", "create_plan"]
            ),
            outputs: Outputs(
                schemas: OutputSchemas(
                    plan: SchemaDefinition(type: "object", required: ["title", "steps"], properties: nil),
                    nextAction: SchemaDefinition(type: "object", required: ["action"], properties: nil),
                    weeklyReview: SchemaDefinition(type: "object", required: ["wins", "challenges"], properties: nil)
                ),
                renderingHints: RenderingHints(
                    primaryCard: "NextAction",
                    maxCardsPerResponse: 2
                )
            )
        )
    }
    
    private func buildSystemPrompt() -> String {
        var prompt = """
        You are \(title), an AI coach specializing in \(selectedSpecialty.rawValue).
        
        Your promise to users: \(promise)
        
        Coaching Style: \(selectedStyle.description)
        Tone: \(toneLabel)
        
        Your approach:
        - Be \(selectedStyle.rawValue) in your communication
        - Focus on \(selectedSpecialty.rawValue) and related areas
        - Help users take concrete action
        - Ask clarifying questions when needed
        - Offer systems and frameworks when appropriate
        
        Remember:
        - You're a coach, not a therapist or medical professional
        - Encourage users to seek professional help when appropriate
        - Respect user context and preferences
        - Keep responses focused and actionable
        """
        
        // Add custom prompt if provided
        if !customSystemPrompt.isEmpty {
            prompt += "\n\nAdditional Instructions:\n\(customSystemPrompt)"
        }
        
        return prompt
    }
    
    private func generateSamplePrompts() -> [String] {
        switch selectedSpecialty {
        case .focus:
            return [
                "I'm feeling stuck on a project",
                "Help me prioritize my tasks",
                "I keep getting distracted"
            ]
        case .planning:
            return [
                "Help me plan my week",
                "I need to organize my goals",
                "Create a review system for me"
            ]
        case .creativity:
            return [
                "I'm experiencing creative block",
                "Help me brainstorm ideas",
                "How do I ship more work?"
            ]
        case .decision:
            return [
                "I'm stuck between two options",
                "Help me make this decision",
                "What framework should I use?"
            ]
        case .wellness:
            return [
                "Help me build better habits",
                "I need a wellness routine",
                "How do I manage stress?"
            ]
        case .business:
            return [
                "Help me with my business strategy",
                "I need to make a business decision",
                "How do I grow my business?"
            ]
        }
    }
}
