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
    @Published var avatarURL: String? // Store the Firebase Storage URL
    @Published var isGeneratingAvatar = false
    
    // Specialty & Style
    @Published var selectedSpecialty: String?
    @Published var customSpecialty = ""
    @Published var selectedStyle: String?
    @Published var customStyle = ""
    
    // Fine-tuning
    @Published var tone: Double = 0.5
    @Published var verbosity: Double = 0.5
    @Published var customSystemPrompt = ""
    
    // Voice
    @Published var selectedVoice: SelectedVoice?
    @Published var voiceEnabled = false
    
    // UI State
    @Published var currentStep = 1
    @Published var isCreating = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    let apiClient: SimonAPI
    private let onCoachCreated: (Coach) -> Void
    
    var canCreate: Bool {
        !title.isEmpty && 
        !promise.isEmpty && 
        avatarImage != nil &&
        selectedSpecialty != nil &&
        selectedStyle != nil
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
    
    var verbosityLabel: String {
        if verbosity < 0.3 {
            return "Concise"
        } else if verbosity < 0.7 {
            return "Balanced"
        } else {
            return "Detailed"
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
                    specialty: selectedSpecialty ?? "general",
                    style: selectedStyle ?? "professional"
                )
                
                // Prefer URL if available, otherwise use base64
                if let imageUrl = response.imageUrl, !imageUrl.isEmpty {
                    // Store the URL for later use
                    avatarURL = imageUrl
                    
                    // Download and display the image asynchronously
                    if let url = URL(string: imageUrl) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            avatarImage = image
                            avatarImageData = data
                            currentStep = max(currentStep, 2)
                            HapticManager.shared.success()
                        } else {
                            throw NSError(domain: "CoachBuilder", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Failed to decode avatar image from URL"
                            ])
                        }
                    } else {
                        throw NSError(domain: "CoachBuilder", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "Invalid avatar URL"
                        ])
                    }
                } else {
                    // Fall back to base64
                    if let imageData = Data(base64Encoded: response.imageData),
                       let image = UIImage(data: imageData) {
                        avatarImage = image
                        avatarImageData = imageData
                        currentStep = max(currentStep, 2)
                        HapticManager.shared.success()
                    } else {
                        throw NSError(domain: "CoachBuilder", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode avatar image"
                        ])
                    }
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
        
        // Prevent duplicate submissions
        guard !isCreating else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Build complete CoachSpec with all tools enabled
                let coachSpec = buildCompleteCoachSpec()
                
                // Determine tags from specialty
                let tags = [selectedSpecialty?.lowercased() ?? "general"]
                
                // Create coach with avatar URL
                let coach = try await apiClient.createCoach(
                    title: title,
                    promise: promise,
                    tags: tags,
                    coachSpec: coachSpec,
                    avatarData: avatarImageData,
                    avatarURL: avatarURL
                )
                
                HapticManager.shared.success()
                onCoachCreated(coach)
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.shared.error()
                isCreating = false  // Re-enable on error
            }
            
            // Don't reset isCreating on success - prevents double creation
        }
    }
    
    private func buildCompleteCoachSpec() -> CoachSpec {
        // Build identity
        let identity = Identity(
            name: title,
            tagline: promise,
            niche: selectedSpecialty?.lowercased() ?? "general",
            audience: ["professionals", "individuals"],
            problemStatements: generateProblemStatements(),
            outcomes: generateOutcomes(),
            persona: Persona(
                archetype: getArchetype(),
                voice: buildVoiceDescription(),
                boundaries: ["No medical advice", "No legal advice", "No financial advice"]
            ),
            samplePrompts: generateSamplePrompts()
        )
        
        // Build style
        let style = Style(
            tone: getToneValue(),
            verbosity: getVerbosityValue(),
            formatting: getFormatting(),
            interactionRules: InteractionRules(
                askOneQuestionAtATime: true,
                confirmBeforeScheduling: true,
                avoidMotivationalFluff: selectedStyle?.lowercased().contains("direct") ?? false,
                reflectUserLanguage: true
            )
        )
        
        // Build methods with frameworks
        let methods = Methods(
            frameworks: nil,
            defaultProtocols: DefaultProtocols(
                quickNudge: Protocol(
                    template: ["Clarify the situation", "Suggest next step", "Confirm action"],
                    phases: nil
                ),
                deepSession: Protocol(
                    template: nil,
                    phases: ["Explore context", "Identify patterns", "Create plan", "Commit to action"]
                )
            )
        )
        
        // Build policies
        let policies = Policies(
            refusals: Refusals(
                medical: true,
                legal: true,
                financialAdvice: "general_only",
                selfHarm: "escalate_support"  // Changed from "immediate_resources" to valid value
            ),
            privacy: Privacy(
                storeSensitiveMemory: false,
                redactPatterns: ["ssn", "credit_card", "password", "api_key"],
                userControls: ["memory_export", "memory_delete", "memory_view"]
            ),
            safety: Safety(
                noManipulation: true,
                noGuilt: true,
                noShaming: true
            )
        )
        
        // Build tools - ALL TOOLS ENABLED BY DEFAULT
        let toolsAllowed = ToolsAllowed(
            clientTools: [
                "calendar_event_create",
                "reminder_create",
                "local_notification_schedule",
                "share_sheet_export"
            ],
            serverTools: [
                "memory_read",
                "memory_write",
                "plan_create",
                "plan_update",
                "plan_list_active",
                "checkin_schedule"
            ],
            requiresUserConfirmation: [
                "calendar_event_create",
                "reminder_create",
                "local_notification_schedule"
            ]
        )
        
        // Build outputs
        let outputs = Outputs(
            schemas: OutputSchemas(
                plan: SchemaDefinition(
                    type: "object",
                    required: ["title", "objective", "horizon", "milestones", "next_actions"],
                    properties: [
                        "title": ["type": "string"],
                        "objective": ["type": "string"],
                        "horizon": ["type": "string"],
                        "milestones": ["type": "array"],
                        "next_actions": ["type": "array"]
                    ]
                ),
                nextAction: SchemaDefinition(
                    type: "object",
                    required: ["id", "title", "duration_min", "energy", "when"],
                    properties: [
                        "id": ["type": "string"],
                        "title": ["type": "string"],
                        "duration_min": ["type": "integer"],
                        "energy": ["type": "string"],
                        "when": ["type": "string"]
                    ]
                ),
                weeklyReview: SchemaDefinition(
                    type: "object",
                    required: ["wins", "misses", "root_causes", "next_week_focus", "commitments"],
                    properties: [
                        "wins": ["type": "array"],
                        "misses": ["type": "array"],
                        "root_causes": ["type": "array"],
                        "next_week_focus": ["type": "array"],
                        "commitments": ["type": "array"]
                    ]
                )
            ),
            renderingHints: RenderingHints(
                primaryCard: "next_actions",
                maxCardsPerResponse: 2
            )
        )
        
        // Build voice config if enabled
        let voiceConfig: VoiceConfig? = voiceEnabled && selectedVoice != nil ? VoiceConfig(
            enabled: true,
            voiceID: selectedVoice?.voiceID,
            voiceName: selectedVoice?.voiceName,
            stability: selectedVoice?.settings.stability ?? 0.5,
            similarity: selectedVoice?.settings.similarityBoost ?? 0.75,
            style: selectedVoice?.settings.style,
            presetName: selectedVoice?.presetName
        ) : nil
        
        return CoachSpec(
            version: "1.0",
            identity: identity,
            style: style,
            methods: methods,
            policies: policies,
            toolsAllowed: toolsAllowed,
            outputs: outputs,
            voice: voiceConfig
        )
    }
    
    // MARK: - Helper Methods
    
    private func getArchetype() -> String {
        let style = selectedStyle?.lowercased() ?? ""
        if style.contains("direct") { return "strategist" }
        if style.contains("warm") || style.contains("supportive") { return "mentor" }
        if style.contains("socratic") { return "philosopher" }
        if style.contains("analytical") { return "analyst" }
        if style.contains("motivational") { return "champion" }
        if style.contains("pragmatic") { return "practitioner" }
        return "coach"
    }
    
    private func getToneValue() -> String {
        let style = selectedStyle?.lowercased() ?? ""
        if style.contains("direct") { return "direct_clear" }
        if style.contains("warm") { return "warm_encouraging" }
        if style.contains("socratic") { return "socratic_clear" }
        if style.contains("analytical") { return "analytical_supportive" }
        if style.contains("motivational") { return "energetic_inspiring" }
        if style.contains("pragmatic") { return "practical_grounded" }
        return "balanced_supportive"
    }
    
    private func getVerbosityValue() -> String {
        if verbosity < 0.3 { return "concise" }
        if verbosity > 0.7 { return "detailed" }
        return "medium"
    }
    
    private func buildVoiceDescription() -> String {
        var voice = "You are \(title), a professional AI coach"
        
        if !customSystemPrompt.isEmpty {
            voice += ". " + customSystemPrompt
        } else if let style = selectedStyle {
            voice += " with a \(style.lowercased()) approach"
        }
        
        voice += ". Your promise: \(promise)"
        
        return voice
    }
    
    private func getFormatting() -> Formatting {
        let maxBullets = verbosity < 0.3 ? 4 : (verbosity > 0.7 ? 7 : 5)
        let maxSentences = verbosity < 0.3 ? 2 : (verbosity > 0.7 ? 4 : 3)
        
        return Formatting(
            maxBullets: maxBullets,
            maxSentencesPerParagraph: maxSentences,
            alwaysEndWith: ["What would you like to do next?"],
            useEmoji: "sparingly",
            allowedMarkdown: ["bullet_list", "numbered_list", "bold"]
        )
    }
    
    private func generateProblemStatements() -> [String] {
        // Generic problem statements - backend will enhance these
        return [
            "I need guidance in this area",
            "I want to improve",
            "I'm facing challenges"
        ]
    }
    
    private func generateOutcomes() -> [String] {
        return [
            "Achieve clarity",
            "Take action",
            "Build momentum"
        ]
    }
    
    private func generateSamplePrompts() -> [String] {
        return [
            "Help me get started",
            "I need guidance",
            "What should I focus on?"
        ]
    }
}
