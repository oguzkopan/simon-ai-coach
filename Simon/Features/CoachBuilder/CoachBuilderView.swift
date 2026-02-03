import SwiftUI

struct CoachBuilderView: View {
    @StateObject private var viewModel: CoachBuilderViewModel
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: CoachBuilderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Section
                    avatarSection
                    
                    // Basic Info Section
                    basicInfoSection
                    
                    // Specialty Section
                    specialtySection
                    
                    // Style Section
                    styleSection
                    
                    // Advanced Options
                    advancedSection
                    
                    // Create Button
                    createButton
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Create Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.accentPrimary)
                }
            }
            .overlay {
                if viewModel.isGeneratingAvatar {
                    avatarGenerationOverlay
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        VStack(spacing: 16) {
            Text("Coach Avatar")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Avatar Prompt
            VStack(alignment: .leading, spacing: 8) {
                Text("Avatar Description")
                    .font(theme.font(15, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Describe your coach's appearance...", text: $viewModel.avatarPrompt, axis: .vertical)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .lineLimit(3...6)
            }
            
            Button(action: { viewModel.generateAvatar() }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Avatar")
                        .font(theme.font(15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.accentPrimary)
                .cornerRadius(12)
            }
            .disabled(viewModel.avatarPrompt.isEmpty || viewModel.isGeneratingAvatar)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            Text("Basic Information")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
                Text("Promise")
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
    
    // MARK: - Specialty Section
    
    private var specialtySection: some View {
        VStack(spacing: 16) {
            Text("Specialty")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CoachSpecialty.allCases, id: \.self) { specialty in
                    SpecialtyChip(
                        specialty: specialty,
                        isSelected: viewModel.selectedSpecialty == specialty,
                        action: { viewModel.selectedSpecialty = specialty }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Style Section
    
    private var styleSection: some View {
        VStack(spacing: 16) {
            Text("Coaching Style")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(CoachingStyle.allCases, id: \.self) { style in
                    StyleOption(
                        style: style,
                        isSelected: viewModel.selectedStyle == style,
                        action: { viewModel.selectedStyle = style }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Advanced Options")
                    .font(theme.font(17, weight: .semibold))
                
                Spacer()
                
                Button(action: { withAnimation { viewModel.showAdvanced.toggle() } }) {
                    Image(systemName: viewModel.showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
            }
            
            if viewModel.showAdvanced {
                VStack(alignment: .leading, spacing: 16) {
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
                        
                        Slider(value: $viewModel.tone, in: 0...1, step: 0.1)
                            .tint(theme.accentPrimary)
                    }
                    
                    // System Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom System Prompt (Optional)")
                            .font(theme.font(15, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Add custom instructions...", text: $viewModel.customSystemPrompt, axis: .vertical)
                            .font(theme.font(14))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .lineLimit(4...8)
                    }
                }
            }
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
    
    private var avatarGenerationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Generating Avatar...")
                    .font(theme.font(17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("This may take a moment")
                    .font(theme.font(14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Color(.systemGray))
            .cornerRadius(20)
        }
    }
}

// MARK: - Supporting Views

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
                
                Text(specialty.rawValue.capitalized)
                    .font(theme.font(13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
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
    case focus
    case planning
    case creativity
    case decision
    case wellness
    case business
    
    var icon: String {
        switch self {
        case .focus: return "target"
        case .planning: return "calendar"
        case .creativity: return "lightbulb.fill"
        case .decision: return "arrow.triangle.branch"
        case .wellness: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum CoachingStyle: String, CaseIterable {
    case direct
    case warm
    case socratic
    
    var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .warm: return "Warm & Supportive"
        case .socratic: return "Socratic"
        }
    }
    
    var description: String {
        switch self {
        case .direct: return "Clear, actionable guidance"
        case .warm: return "Encouraging and empathetic"
        case .socratic: return "Questions that guide discovery"
        }
    }
}
