import SwiftUI

struct CoachBuilderView: View {
    @StateObject private var viewModel: CoachBuilderViewModel
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var showVoiceSelection = false
    
    init(viewModel: CoachBuilderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar Section
                avatarSection
                    
                    // Basic Info Section
                    basicInfoSection
                    
                    // Specialty Section (Expanded)
                    specialtySection
                    
                    // Style Section (Expanded)
                    styleSection
                    
                    // Tone & Verbosity Section
                    toneSection
                    
                    // Voice Selection Section
                    voiceSection
                    
                    // Custom System Prompt Section
                    customPromptSection
                    
                    // Tool Permissions Section
                    toolPermissionsSection
                    
                    // Create Button
                    createButton
                }
                .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create Coach")
        .sheet(isPresented: $showVoiceSelection) {
            VoiceSelectionView(
                selectedVoice: $viewModel.selectedVoice,
                voiceEnabled: $viewModel.voiceEnabled,
                apiClient: viewModel.apiClient
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Coach Avatar")
                    .font(theme.font(17, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(viewModel.avatarImage != nil ? .green : Color(.systemGray4))
            }
            
            // Avatar Preview
            ZStack {
                if let avatarImage = viewModel.avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)
                        .overlay {
                            if viewModel.isGeneratingAvatar {
                                // Show loading indicator while generating
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .tint(theme.accentPrimary)
                                    
                                    Text("Generating...")
                                        .font(theme.font(12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Avatar Prompt
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe your coach's appearance")
                    .font(theme.font(15, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Professional woman with glasses, warm smile...", text: $viewModel.avatarPrompt, axis: .vertical)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(3...6)
                    .disabled(viewModel.isGeneratingAvatar)
            }
            
            Button(action: { viewModel.generateAvatar() }) {
                HStack {
                    if viewModel.isGeneratingAvatar {
                        ProgressView()
                            .tint(.white)
                        Text("Generating...")
                            .font(theme.font(15, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                        Text("Generate Avatar")
                            .font(theme.font(15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isGeneratingAvatar ? Color.gray : theme.accentPrimary)
                .cornerRadius(12)
            }
            .disabled(viewModel.avatarPrompt.isEmpty || viewModel.isGeneratingAvatar)
            
            // Show helpful message while generating
            if viewModel.isGeneratingAvatar {
                Text("This may take up to 60 seconds. Feel free to fill out other sections below.")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Basic Information")
                    .font(theme.font(17, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor((!viewModel.title.isEmpty && !viewModel.promise.isEmpty) ? .green : Color(.systemGray4))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Coach Name")
                    .font(theme.font(15, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Focus Sprint Coach", text: $viewModel.title)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Promise / Tagline")
                    .font(theme.font(15, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("What will this coach help with?", text: $viewModel.promise, axis: .vertical)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(2...4)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Specialty Section (Expanded with Custom Option)
    
    private var specialtySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Specialty")
                    .font(theme.font(17, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(viewModel.selectedSpecialty != nil ? .green : Color(.systemGray4))
            }
            
            Text("Choose the primary area this coach will focus on")
                .font(theme.font(13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CoachSpecialty.allCases, id: \.self) { specialty in
                    SpecialtyChip(
                        specialty: specialty,
                        isSelected: viewModel.selectedSpecialty == specialty.rawValue,
                        action: { 
                            viewModel.selectedSpecialty = specialty.rawValue
                            viewModel.customSpecialty = ""
                        }
                    )
                }
            }
            
            // Custom Specialty Option
            VStack(alignment: .leading, spacing: 8) {
                Text("Or enter custom specialty")
                    .font(theme.font(13, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Time Management, Public Speaking...", text: $viewModel.customSpecialty)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: viewModel.customSpecialty) { _, newValue in
                        if !newValue.isEmpty {
                            viewModel.selectedSpecialty = newValue
                        }
                    }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Style Section (Expanded with Custom Option)
    
    private var styleSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Coaching Style")
                    .font(theme.font(17, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(viewModel.selectedStyle != nil ? .green : Color(.systemGray4))
            }
            
            Text("How should this coach communicate?")
                .font(theme.font(13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(CoachingStyle.allCases, id: \.self) { style in
                    StyleOption(
                        style: style,
                        isSelected: viewModel.selectedStyle == style.rawValue,
                        action: { 
                            viewModel.selectedStyle = style.rawValue
                            viewModel.customStyle = ""
                        }
                    )
                }
            }
            
            // Custom Style Option
            VStack(alignment: .leading, spacing: 8) {
                Text("Or describe custom style")
                    .font(theme.font(13, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Humorous and lighthearted...", text: $viewModel.customStyle, axis: .vertical)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(2...4)
                    .onChange(of: viewModel.customStyle) { _, newValue in
                        if !newValue.isEmpty {
                            viewModel.selectedStyle = newValue
                        }
                    }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Tone Section
    
    private var toneSection: some View {
        VStack(spacing: 16) {
            Text("Fine-Tuning")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tone Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tone")
                        .font(theme.font(15, weight: .medium))
                    Spacer()
                    Text(viewModel.toneLabel)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Gentle")
                        .font(theme.font(12))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.tone, in: 0...1, step: 0.1)
                        .tint(theme.accentPrimary)
                    
                    Text("Intense")
                        .font(theme.font(12))
                        .foregroundColor(.secondary)
                }
            }
            
            // Verbosity Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Response Length")
                        .font(theme.font(15, weight: .medium))
                    Spacer()
                    Text(viewModel.verbosityLabel)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Concise")
                        .font(theme.font(12))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.verbosity, in: 0...1, step: 0.1)
                        .tint(theme.accentPrimary)
                    
                    Text("Detailed")
                        .font(theme.font(12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Voice Section
    
    private var voiceSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Voice Settings")
                    .font(theme.font(17, weight: .semibold))
                Spacer()
                if viewModel.voiceEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Button(action: { showVoiceSelection = true }) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.voiceEnabled ? "Voice Enabled" : "Add Voice")
                            .font(theme.font(15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let voice = viewModel.selectedVoice {
                            Text(voice.voiceName)
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Optional: Enable voice coaching")
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Custom Prompt Section
    
    private var customPromptSection: some View {
        VStack(spacing: 16) {
            Text("Custom Instructions (Optional)")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Add specific instructions or personality traits for this coach")
                .font(theme.font(13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("e.g., Always start with a question, use metaphors from sports...", text: $viewModel.customSystemPrompt, axis: .vertical)
                .font(theme.font(14))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(4...8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Tool Permissions Section
    
    private var toolPermissionsSection: some View {
        VStack(spacing: 16) {
            Text("Tool Permissions")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("All tools are enabled by default. Your coach will have access to:")
                .font(theme.font(13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                ToolPermissionRow(icon: "calendar", title: "Calendar Events", description: "Create and manage calendar events")
                ToolPermissionRow(icon: "bell", title: "Reminders", description: "Set reminders and notifications")
                ToolPermissionRow(icon: "list.bullet.clipboard", title: "Plans & Actions", description: "Create structured plans and next actions")
                ToolPermissionRow(icon: "brain", title: "Memory", description: "Remember context and preferences")
                ToolPermissionRow(icon: "magnifyingglass", title: "Web Search", description: "Search for current information")
                ToolPermissionRow(icon: "arrow.triangle.2.circlepath", title: "Future Tools", description: "Access to new tools as they're added")
            }
            
            Text("Note: Some actions will require your confirmation before execution")
                .font(theme.font(12))
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button(action: { viewModel.createCoach() }) {
            HStack {
                if viewModel.isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create Coach")
                        .font(theme.font(17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canCreate ? theme.accentPrimary : Color.gray)
            .cornerRadius(16)
        }
        .disabled(!viewModel.canCreate || viewModel.isCreating)
    }
    
    // MARK: - Avatar Generation Overlay
}

// MARK: - Supporting Views

struct ToolPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.font(14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(theme.font(12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

struct SpecialtyChip: View {
    let specialty: CoachSpecialty
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: specialty.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : theme.accentPrimary)
                
                Text(specialty.displayName)
                    .font(theme.font(13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? theme.accentPrimary : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct StyleOption: View {
    let style: CoachingStyle
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.accentPrimary : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(theme.accentPrimary)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(style.description)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? theme.accentTint : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enums

enum CoachSpecialty: String, CaseIterable {
    case focus = "focus"
    case planning = "planning"
    case creativity = "creativity"
    case decision = "decision"
    case wellness = "wellness"
    case business = "business"
    case leadership = "leadership"
    case learning = "learning"
    case career = "career"
    case productivity = "productivity"
    case relationships = "relationships"
    case finance = "finance"
    
    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .planning: return "Planning"
        case .creativity: return "Creativity"
        case .decision: return "Decision Making"
        case .wellness: return "Wellness"
        case .business: return "Business"
        case .leadership: return "Leadership"
        case .learning: return "Learning"
        case .career: return "Career"
        case .productivity: return "Productivity"
        case .relationships: return "Relationships"
        case .finance: return "Finance"
        }
    }
    
    var icon: String {
        switch self {
        case .focus: return "target"
        case .planning: return "calendar"
        case .creativity: return "lightbulb.fill"
        case .decision: return "arrow.triangle.branch"
        case .wellness: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .leadership: return "person.3.fill"
        case .learning: return "book.fill"
        case .career: return "briefcase.fill"
        case .productivity: return "checkmark.circle.fill"
        case .relationships: return "heart.fill"
        case .finance: return "dollarsign.circle.fill"
        }
    }
}

enum CoachingStyle: String, CaseIterable {
    case direct = "direct"
    case warm = "warm"
    case socratic = "socratic"
    case analytical = "analytical"
    case motivational = "motivational"
    case pragmatic = "pragmatic"
    
    var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .warm: return "Warm & Supportive"
        case .socratic: return "Socratic"
        case .analytical: return "Analytical"
        case .motivational: return "Motivational"
        case .pragmatic: return "Pragmatic"
        }
    }
    
    var description: String {
        switch self {
        case .direct: return "Clear, actionable guidance without fluff"
        case .warm: return "Encouraging and empathetic support"
        case .socratic: return "Questions that guide discovery"
        case .analytical: return "Systematic and logical approach"
        case .motivational: return "Inspiring and confidence-building"
        case .pragmatic: return "Practical, real-world solutions"
        }
    }
}
