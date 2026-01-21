import SwiftUI

struct CoachDetailView: View {
    let coach: Coach
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var showSignInPrompt = false
    @State private var isStartingSession = false
    @State private var errorMessage: String?
    
    var onStartChat: ((String) -> Void)?
    private let apiClient: SimonAPIClient
    
    init(coach: Coach, apiClient: SimonAPIClient, onStartChat: ((String) -> Void)? = nil) {
        self.coach = coach
        self.apiClient = apiClient
        self.onStartChat = onStartChat
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                VStack(alignment: .center, spacing: 12) {
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
                .padding(.vertical, 20)
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
                if let samplePrompts = extractSamplePrompts() {
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow Context Access")
                                .font(theme.font(15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Coach can read your recent context to give relevant advice.")
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                
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
                    
                    // Bookmark button
                    Button(action: { /* TODO: Implement bookmark */ }) {
                        HStack {
                            Image(systemName: "bookmark")
                                .font(.system(size: 16))
                            Text("Save for Later")
                                .font(theme.font(15, weight: .medium))
                        }
                        .foregroundColor(theme.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(coach.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignInPrompt) {
            SignInPromptView(showSignIn: .constant(false))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func extractSamplePrompts() -> [String]? {
        // Extract sample prompts from blueprint if available
        // For now, return some generic prompts based on coach type
        let prompts = [
            "Help me plan my week effectively.",
            "Review my current priorities.",
            "Debug my workflow process."
        ]
        return prompts
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
                    onStartChat?(session.id)
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
        // Start session and send the prompt
        startSession()
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
