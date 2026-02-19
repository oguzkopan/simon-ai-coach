import SwiftUI

struct CoachDetailView: View {
    let coach: Coach
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var showSignInPrompt = false
    @State private var isStartingSession = false
    @State private var errorMessage: String?
    @State private var pendingPrompt: String?
    @State private var includeContext = true
    @State private var isLoadingPreference = true
    @State private var isSaved = false
    @State private var isSaving = false
    @State private var showFullSpec = false
    
    var onStartChat: ((String, String?) -> Void)?
    private let apiClient: SimonAPIClient
    
    init(coach: Coach, apiClient: SimonAPIClient, onStartChat: ((String, String?) -> Void)? = nil) {
        self.coach = coach
        self.apiClient = apiClient
        self.onStartChat = onStartChat
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section with Avatar
                VStack(alignment: .center, spacing: 16) {
                    // Avatar
                    if let avatarUrl = coach.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } placeholder: {
                            // Show shimmer/loading placeholder while avatar loads
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    ProgressView()
                                        .tint(theme.accentPrimary)
                                }
                        }
                    } else {
                        // Only show icon if there's NO avatar URL
                        avatarPlaceholder
                    }
                    
                    Text("AI COACH")
                        .font(theme.font(12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    Text(coach.title)
                        .font(theme.font(28, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                        .frame(width: 40)
                        .padding(.vertical, 4)
                    
                    Text(coach.promise)
                        .font(theme.font(17))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Focus Areas
                if !coach.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus Areas")
                            .font(theme.font(20, weight: .bold))
                            .padding(.horizontal, 20)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(coach.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(theme.font(15))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Sample Prompts
                if let samplePrompts = extractSamplePrompts(), !samplePrompts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sample Prompts")
                            .font(theme.font(20, weight: .bold))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 8) {
                            ForEach(samplePrompts, id: \.self) { prompt in
                                SamplePromptCard(prompt: prompt) {
                                    startSessionWithPrompt(prompt)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Context Access (if applicable)
                if authManager.isAuthenticated {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 20))
                                .foregroundColor(theme.accentPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allow Context Access")
                                    .font(theme.font(15, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Coach can read your values, goals, and recent context to give personalized advice.")
                                    .font(theme.font(13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isLoadingPreference {
                                ProgressView()
                            } else {
                                Toggle("", isOn: $includeContext)
                                    .labelsHidden()
                                    .onChange(of: includeContext) { oldValue, newValue in
                                        updateContextPreference(newValue)
                                    }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // View Full Specification Button
                if coach.coachSpec != nil {
                    Button(action: { showFullSpec = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 16))
                            
                            Text("View Full Specification")
                                .font(theme.font(15, weight: .medium))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // View Events for this Coach - Removed NavigationLink to fix navigation error
                // Events can be accessed from the Library tab or through deep links
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(theme.font(13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                // Start Button
                VStack(spacing: 12) {
                    SButton(
                        isStartingSession ? "Starting..." : "Chat Now",
                        style: .primary,
                        isLoading: isStartingSession,
                        action: startSession
                    )
                    .disabled(isStartingSession)
                    
                    // Save/Unsave button
                    Button(action: toggleSave) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(theme.accentPrimary)
                            } else {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 16))
                                Text(isSaved ? "Saved" : "Save for Later")
                                    .font(theme.font(15, weight: .medium))
                            }
                        }
                        .foregroundColor(theme.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .disabled(isSaving || !authManager.isAuthenticated)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(coach.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContextPreference()
            await checkIfSaved()
        }
        .sheet(isPresented: $showSignInPrompt) {
            SignInPromptView(
                showSignIn: .constant(false),
                iconName: "bookmark.fill",
                title: "Save Your Favorites",
                message: "Sign in to save your favorite coaches and access them anytime across all your devices."
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFullSpec) {
            CoachSpecDetailSheet(coach: coach, apiClient: apiClient)
                .environmentObject(theme)
        }
    }
    
    private func loadContextPreference() async {
        guard authManager.isAuthenticated else {
            isLoadingPreference = false
            return
        }
        
        do {
            let contextData = try await apiClient.getContext()
            await MainActor.run {
                // Use the preference from backend, default to true if not set
                includeContext = contextData.preferences?.includeContext ?? true
                isLoadingPreference = false
            }
        } catch {
            await MainActor.run {
                // Default to true on error
                includeContext = true
                isLoadingPreference = false
            }
        }
    }
    
    private func updateContextPreference(_ enabled: Bool) {
        Task {
            do {
                try await apiClient.updateContextPreference(includeContext: enabled)
            } catch {
                // Revert on error
                await MainActor.run {
                    includeContext = !enabled
                    errorMessage = "Failed to update preference"
                }
            }
        }
    }
    
    private func checkIfSaved() async {
        guard authManager.isAuthenticated else {
            isSaved = false
            return
        }
        
        do {
            let savedCoaches = try await apiClient.getSavedCoaches()
            await MainActor.run {
                isSaved = savedCoaches.contains { $0.id == coach.id }
            }
        } catch {
            // Silently fail - not critical
            await MainActor.run {
                isSaved = false
            }
        }
    }
    
    private func toggleSave() {
        guard authManager.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        
        Task {
            isSaving = true
            errorMessage = nil
            
            do {
                if isSaved {
                    try await apiClient.unsaveCoach(coachId: coach.id)
                    await MainActor.run {
                        isSaved = false
                        isSaving = false
                    }
                } else {
                    try await apiClient.saveCoach(coachId: coach.id)
                    await MainActor.run {
                        isSaved = true
                        isSaving = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to \(isSaved ? "unsave" : "save") coach"
                }
            }
        }
    }
    
    private func extractSamplePrompts() -> [String]? {
        // First try to get from CoachSpec
        if let coachSpec = coach.coachSpec,
           let samplePrompts = coachSpec.identity.samplePrompts,
           !samplePrompts.isEmpty {
            return samplePrompts
        }
        
        // Fallback to generic prompts based on tags
        return generateGenericPrompts()
    }
    
    private func generateGenericPrompts() -> [String]? {
        // Generate contextual prompts based on coach tags
        let tags = coach.tags.map { $0.lowercased() }
        
        if tags.contains("productivity") || tags.contains("systems") {
            return [
                "Help me design a morning routine that sticks",
                "Review my current productivity system",
                "What's one small system I can build this week?"
            ]
        } else if tags.contains("career") || tags.contains("leadership") {
            return [
                "Help me prepare for a difficult conversation",
                "Review my career goals and next steps",
                "How can I be more effective as a leader?"
            ]
        } else if tags.contains("health") || tags.contains("wellness") {
            return [
                "Help me build a sustainable exercise habit",
                "Review my sleep and energy patterns",
                "What's one health change I should prioritize?"
            ]
        } else if tags.contains("learning") || tags.contains("growth") {
            return [
                "Help me create a learning plan",
                "Review my progress on current goals",
                "What skill should I focus on next?"
            ]
        }
        
        // Default prompts
        return [
            "Help me plan my week effectively",
            "Review my current priorities",
            "What should I focus on today?"
        ]
    }
    
    private func startSession() {
        if !authManager.isAuthenticated {
            showSignInPrompt = true
            return
        }
        
        Task {
            isStartingSession = true
            errorMessage = nil
            
            do {
                let session = try await apiClient.createSession(coachID: coach.id)
                await MainActor.run {
                    isStartingSession = false
                    // Pass the session ID and any pending prompt
                    onStartChat?(session.id, pendingPrompt)
                    pendingPrompt = nil
                }
            } catch {
                await MainActor.run {
                    isStartingSession = false
                    errorMessage = "Failed to start session. Please try again."
                }
            }
        }
    }
    
    private func startSessionWithPrompt(_ prompt: String) {
        // Store the prompt and start session
        pendingPrompt = prompt
        startSession()
    }
    
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(getIconColor(for: coach.tags.first ?? ""))
                .frame(width: 80, height: 80)
            
            Image(systemName: getIconName(for: coach.tags.first ?? ""))
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private func getIconColor(for tag: String) -> Color {
        switch tag.lowercased() {
        case "focus", "productivity":
            return Color(hex: "00C7BE") // Teal
        case "planning", "strategy":
            return Color(hex: "FF9500") // Orange
        case "creativity", "creative":
            return Color(hex: "AF52DE") // Purple
        case "business":
            return Color(hex: "5856D6") // Indigo
        case "wellness", "health", "habits":
            return Color(hex: "00C7BE") // Mint
        case "decision":
            return Color(hex: "FF2D55") // Rose
        case "confidence", "mindset":
            return Color(hex: "5856D6") // Indigo
        default:
            return Color(hex: "5856D6") // Default indigo
        }
    }
    
    private func getIconName(for tag: String) -> String {
        switch tag.lowercased() {
        case "focus", "productivity":
            return "target"
        case "planning", "strategy":
            return "calendar"
        case "creativity", "creative":
            return "lightbulb.fill"
        case "business":
            return "chart.line.uptrend.xyaxis"
        case "wellness", "health", "habits":
            return "leaf.fill"
        case "decision":
            return "arrow.triangle.branch"
        case "confidence", "mindset":
            return "star.fill"
        default:
            return "star.fill"
        }
    }
}

// MARK: - Sample Prompt Card
struct SamplePromptCard: View {
    let prompt: String
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(prompt)
                    .font(theme.font(15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
