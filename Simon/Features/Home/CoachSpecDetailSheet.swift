import SwiftUI

struct CoachSpecDetailSheet: View {
    let coach: Coach
    let apiClient: SimonAPIClient
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var isEditing = false
    @State private var editedTagline = ""
    @State private var editedSamplePrompts: [String] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isOwner: Bool {
        authManager.currentUser?.uid == coach.ownerUID
    }
    
    init(coach: Coach, apiClient: SimonAPIClient) {
        self.coach = coach
        self.apiClient = apiClient
        _editedTagline = State(initialValue: coach.coachSpec?.identity.tagline ?? "")
        _editedSamplePrompts = State(initialValue: coach.coachSpec?.identity.samplePrompts ?? [])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let spec = coach.coachSpec {
                        // Header Section
                        headerSection(spec: spec)
                        
                        // Quick Stats
                        statsSection
                        
                        // Identity Section
                        identitySection(spec: spec)
                        
                        // Sample Prompts (Editable)
                        samplePromptsSection(spec: spec)
                        
                        // Persona Section
                        personaSection(spec: spec)
                        
                        // Style Section
                        styleSection(spec: spec)
                        
                        // Frameworks Section
                        if let frameworks = spec.methods.frameworks, !frameworks.isEmpty {
                            frameworksSection(frameworks: frameworks)
                        }
                        
                        // Tools Section
                        toolsSection(spec: spec)
                        
                        // Policies Section
                        policiesSection(spec: spec)
                        
                        // Voice Configuration
                        if let voice = spec.voice {
                            voiceSection(voice: voice)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Coach Specification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if isOwner {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditing {
                            Button(isSaving ? "Saving..." : "Save") {
                                saveChanges()
                            }
                            .disabled(isSaving)
                        } else {
                            Button("Edit") {
                                isEditing = true
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(spec: CoachSpec) -> some View {
        VStack(spacing: 16) {
            if let avatarUrl = coach.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.accentPrimary, lineWidth: 3))
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                        .overlay {
                            ProgressView()
                        }
                }
            }
            
            Text(spec.identity.name)
                .font(theme.font(28, weight: .bold))
                .foregroundColor(.primary)
            
            if isEditing {
                VStack(spacing: 8) {
                    Text("Tagline")
                        .font(theme.font(13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Enter tagline", text: $editedTagline)
                        .font(theme.font(16))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            } else {
                Text(spec.identity.tagline)
                    .font(theme.font(17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 8) {
                ForEach(coach.tags, id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.accentPrimary.opacity(0.15))
                        .cornerRadius(16)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray6).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(icon: "play.circle.fill", label: "Starts", value: "\(coach.stats.starts)", color: .blue)
            StatCard(icon: "bookmark.fill", label: "Saves", value: "\(coach.stats.saves)", color: .orange)
            StatCard(icon: "heart.fill", label: "Upvotes", value: "\(coach.stats.upvotes)", color: .pink)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Identity Section
    
    private func identitySection(spec: CoachSpec) -> some View {
        SpecSection(title: "Identity", icon: "person.circle.fill") {
            InfoRow(label: "Niche", value: spec.identity.niche.capitalized)
            
            if !spec.identity.audience.isEmpty {
                InfoList(label: "Target Audience", items: spec.identity.audience.map { $0.capitalized })
            }
            
            if !spec.identity.problemStatements.isEmpty {
                InfoList(label: "Addresses", items: spec.identity.problemStatements, icon: "exclamationmark.triangle.fill", iconColor: .orange)
            }
            
            if !spec.identity.outcomes.isEmpty {
                InfoList(label: "Outcomes", items: spec.identity.outcomes, icon: "checkmark.circle.fill", iconColor: .green)
            }
        }
    }
    
    // MARK: - Sample Prompts Section
    
    private func samplePromptsSection(spec: CoachSpec) -> some View {
        SpecSection(title: "Sample Prompts", icon: "bubble.left.and.bubble.right.fill") {
            if isEditing {
                VStack(spacing: 12) {
                    ForEach(editedSamplePrompts.indices, id: \.self) { index in
                        HStack {
                            TextField("Prompt \(index + 1)", text: $editedSamplePrompts[index])
                                .font(theme.font(15))
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            Button(action: {
                                editedSamplePrompts.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        editedSamplePrompts.append("")
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Prompt")
                        }
                        .font(theme.font(15, weight: .medium))
                        .foregroundColor(theme.accentPrimary)
                    }
                }
            } else if let prompts = spec.identity.samplePrompts, !prompts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(prompts, id: \.self) { prompt in
                        HStack {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.accentPrimary)
                            Text(prompt)
                                .font(theme.font(15))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Persona Section
    
    private func personaSection(spec: CoachSpec) -> some View {
        SpecSection(title: "Persona", icon: "theatermasks.fill") {
            InfoRow(label: "Archetype", value: spec.identity.persona.archetype.capitalized)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(spec.identity.persona.voice)
                    .font(theme.font(15))
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            if let boundaries = spec.identity.persona.boundaries, !boundaries.isEmpty {
                InfoList(label: "Boundaries", items: boundaries, icon: "hand.raised.fill", iconColor: .red)
            }
        }
    }
    
    // MARK: - Style Section
    
    private func styleSection(spec: CoachSpec) -> some View {
        SpecSection(title: "Communication Style", icon: "text.bubble.fill") {
            HStack(spacing: 16) {
                StyleBadge(label: "Tone", value: spec.style.tone)
                StyleBadge(label: "Verbosity", value: spec.style.verbosity)
            }
            
            VStack(spacing: 12) {
                InfoRow(label: "Max Bullets", value: "\(spec.style.formatting.maxBullets)")
                InfoRow(label: "Max Sentences/Para", value: "\(spec.style.formatting.maxSentencesPerParagraph)")
                InfoRow(label: "Emoji Usage", value: spec.style.formatting.useEmoji.capitalized)
            }
            
            if let alwaysEndWith = spec.style.formatting.alwaysEndWith, !alwaysEndWith.isEmpty {
                InfoList(label: "Always Ends With", items: alwaysEndWith)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Interaction Rules")
                .font(theme.font(15, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ToggleRow(label: "One Question at a Time", isOn: spec.style.interactionRules.askOneQuestionAtATime)
                ToggleRow(label: "Confirm Before Scheduling", isOn: spec.style.interactionRules.confirmBeforeScheduling)
                ToggleRow(label: "Avoid Motivational Fluff", isOn: spec.style.interactionRules.avoidMotivationalFluff)
                ToggleRow(label: "Reflect User Language", isOn: spec.style.interactionRules.reflectUserLanguage)
            }
        }
    }
    
    // MARK: - Frameworks Section
    
    private func frameworksSection(frameworks: [Framework]) -> some View {
        SpecSection(title: "Coaching Frameworks", icon: "square.grid.3x3.fill") {
            ForEach(frameworks.indices, id: \.self) { index in
                let framework = frameworks[index]
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(framework.name)
                            .font(theme.font(17, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text(framework.goal)
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                    
                    if let steps = framework.steps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Steps:")
                                .font(theme.font(13, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(steps.indices, id: \.self) { stepIndex in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(stepIndex + 1).")
                                        .font(theme.font(13, weight: .bold))
                                        .foregroundColor(theme.accentPrimary)
                                    Text(steps[stepIndex])
                                        .font(theme.font(14))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    if let whenToUse = framework.whenToUse, !whenToUse.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("When to Use:")
                                .font(theme.font(13, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(whenToUse, id: \.self) { situation in
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.accentPrimary)
                                    Text(situation)
                                        .font(theme.font(14))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                
                if index < frameworks.count - 1 {
                    Divider().padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Tools Section
    
    private func toolsSection(spec: CoachSpec) -> some View {
        SpecSection(title: "Available Tools", icon: "wrench.and.screwdriver.fill") {
            if let clientTools = spec.toolsAllowed.clientTools, !clientTools.isEmpty {
                InfoList(label: "Client Tools", items: clientTools, icon: "iphone", iconColor: .blue)
            }
            
            if let serverTools = spec.toolsAllowed.serverTools, !serverTools.isEmpty {
                InfoList(label: "Server Tools", items: serverTools, icon: "server.rack", iconColor: .purple)
            }
            
            if let requiresConfirmation = spec.toolsAllowed.requiresUserConfirmation, !requiresConfirmation.isEmpty {
                InfoList(label: "Requires Confirmation", items: requiresConfirmation, icon: "checkmark.shield.fill", iconColor: .orange)
            }
        }
    }
    
    // MARK: - Policies Section
    
    private func policiesSection(spec: CoachSpec) -> some View {
        SpecSection(title: "Safety & Privacy", icon: "shield.fill") {
            VStack(spacing: 12) {
                PolicyRow(label: "Medical Advice", status: spec.policies.refusals.medical ? "Refused" : "Allowed", isRefused: spec.policies.refusals.medical)
                PolicyRow(label: "Legal Advice", status: spec.policies.refusals.legal ? "Refused" : "Allowed", isRefused: spec.policies.refusals.legal)
                PolicyRow(label: "Financial Advice", status: spec.policies.refusals.financialAdvice, isRefused: spec.policies.refusals.financialAdvice != "allowed")
            }
            
            Divider().padding(.vertical, 8)
            
            VStack(spacing: 8) {
                InfoRow(label: "Store Sensitive Memory", value: spec.policies.privacy.storeSensitiveMemory ? "Yes" : "No")
                
                if let redactPatterns = spec.policies.privacy.redactPatterns, !redactPatterns.isEmpty {
                    InfoList(label: "Redact Patterns", items: redactPatterns, icon: "eye.slash.fill", iconColor: .red)
                }
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Safety Guarantees")
                .font(theme.font(15, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                SafetyBadge(label: "No Manipulation", enabled: spec.policies.safety.noManipulation)
                SafetyBadge(label: "No Guilt", enabled: spec.policies.safety.noGuilt)
                SafetyBadge(label: "No Shaming", enabled: spec.policies.safety.noShaming)
            }
        }
    }
    
    // MARK: - Voice Section
    
    private func voiceSection(voice: VoiceConfig) -> some View {
        SpecSection(title: "Voice Configuration", icon: "waveform") {
            InfoRow(label: "Enabled", value: voice.enabled ? "Yes" : "No")
            
            if let voiceName = voice.voiceName {
                InfoRow(label: "Voice", value: voiceName)
            }
            
            HStack(spacing: 16) {
                VStack {
                    Text("Stability")
                        .font(theme.font(12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", voice.stability * 100))
                        .font(theme.font(20, weight: .bold))
                        .foregroundColor(theme.accentPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack {
                    Text("Similarity")
                        .font(theme.font(12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", voice.similarity * 100))
                        .font(theme.font(20, weight: .bold))
                        .foregroundColor(theme.accentPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Specification Available")
                .font(theme.font(20, weight: .semibold))
                .foregroundColor(.primary)
            Text("This coach doesn't have a detailed specification yet.")
                .font(theme.font(15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() {
        // TODO: Implement save functionality
        // This would call an API endpoint to update the coach
        isSaving = true
        
        Task {
            do {
                // Simulate API call
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    isSaving = false
                    isEditing = false
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save changes"
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(value)
                .font(theme.font(20, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(theme.font(12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct SpecSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @EnvironmentObject private var theme: ThemeStore
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentPrimary)
                Text(title)
                    .font(theme.font(22, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack {
            Text(label)
                .font(theme.font(14, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(theme.font(14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct InfoList: View {
    let label: String
    let items: [String]
    var icon: String = "circle.fill"
    var iconColor: Color = .blue
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(theme.font(14, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundColor(iconColor)
                        Text(item)
                            .font(theme.font(14))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct StyleBadge: View {
    let label: String
    let value: String
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(theme.font(12, weight: .medium))
                .foregroundColor(.secondary)
            Text(value.capitalized)
                .font(theme.font(15, weight: .bold))
                .foregroundColor(theme.accentPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.accentPrimary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ToggleRow: View {
    let label: String
    let isOn: Bool
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack {
            Text(label)
                .font(theme.font(14))
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isOn ? .green : .secondary)
        }
    }
}

struct PolicyRow: View {
    let label: String
    let status: String
    let isRefused: Bool
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack {
            Text(label)
                .font(theme.font(14, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(status)
                .font(theme.font(14, weight: .semibold))
                .foregroundColor(isRefused ? .red : .green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isRefused ? Color.red : Color.green).opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct SafetyBadge: View {
    let label: String
    let enabled: Bool
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.shield.fill" : "xmark.shield.fill")
                .foregroundColor(enabled ? .green : .red)
            Text(label)
                .font(theme.font(14))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
