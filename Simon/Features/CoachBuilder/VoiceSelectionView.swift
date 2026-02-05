import SwiftUI
import AVFoundation
import Combine

struct VoiceSelectionView: View {
    @EnvironmentObject private var theme: ThemeStore
    @StateObject private var viewModel: VoiceSelectionViewModel
    @Binding var selectedVoice: SelectedVoice?
    @Binding var voiceEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(selectedVoice: Binding<SelectedVoice?>, voiceEnabled: Binding<Bool>, apiClient: SimonAPI) {
        _selectedVoice = selectedVoice
        _voiceEnabled = voiceEnabled
        _viewModel = StateObject(wrappedValue: VoiceSelectionViewModel(apiClient: apiClient))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Enable Voice Toggle
                    enableVoiceSection
                    
                    if voiceEnabled {
                        // Voice Selection Mode
                        selectionModeSection
                        
                        // Voice List or Presets
                        if viewModel.selectionMode == .preset {
                            presetsSection
                        } else {
                            voicesSection
                        }
                        
                        // Voice Settings
                        if selectedVoice != nil {
                            voiceSettingsSection
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.accentPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accentPrimary)
                    .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.loadVoices()
            }
        }
    }
    
    // MARK: - Enable Voice Section
    
    private var enableVoiceSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Voice Coaching")
                        .font(theme.font(17, weight: .semibold))
                    
                    Text("Allow this coach to speak responses using AI voice")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $voiceEnabled)
                    .labelsHidden()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Selection Mode Section
    
    private var selectionModeSection: some View {
        VStack(spacing: 12) {
            Text("Voice Selection")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ModeButton(
                    title: "Presets",
                    icon: "star.fill",
                    isSelected: viewModel.selectionMode == .preset,
                    action: { viewModel.selectionMode = .preset }
                )
                
                ModeButton(
                    title: "All Voices",
                    icon: "waveform",
                    isSelected: viewModel.selectionMode == .custom,
                    action: { viewModel.selectionMode = .custom }
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(spacing: 16) {
            Text("Voice Presets")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load presets")
                        .font(theme.font(15, weight: .medium))
                    Text(error)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await viewModel.loadVoices() }
                    }
                    .font(theme.font(14, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                }
                .padding(40)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.presets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: selectedVoice?.presetName == preset.name,
                            action: {
                                // Use first available voice with this preset
                                if let voice = viewModel.voices.first {
                                    selectedVoice = SelectedVoice(
                                        voiceID: voice.voiceID,
                                        voiceName: voice.name,
                                        settings: preset.settings,
                                        presetName: preset.name
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Voices Section
    
    private var voicesSection: some View {
        VStack(spacing: 16) {
            Text("Available Voices")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load voices")
                        .font(theme.font(15, weight: .medium))
                    Text(error)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await viewModel.loadVoices() }
                    }
                    .font(theme.font(14, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
                }
                .padding(40)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.voices) { voice in
                        VoiceCard(
                            voice: voice,
                            isSelected: selectedVoice?.voiceID == voice.voiceID,
                            action: {
                                selectedVoice = SelectedVoice(
                                    voiceID: voice.voiceID,
                                    voiceName: voice.name,
                                    settings: voice.settings ?? VoiceSettings(
                                        stability: 0.5,
                                        similarityBoost: 0.75,
                                        style: nil,
                                        useSpeakerBoost: nil
                                    ),
                                    presetName: nil
                                )
                            },
                            onPreview: {
                                viewModel.previewVoice(voice)
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Voice Settings Section
    
    private var voiceSettingsSection: some View {
        VStack(spacing: 16) {
            Text("Voice Settings")
                .font(theme.font(17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let voice = selectedVoice {
                VStack(alignment: .leading, spacing: 16) {
                    // Stability
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stability")
                                .font(theme.font(15, weight: .medium))
                            Spacer()
                            Text(String(format: "%.2f", voice.settings.stability))
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("More stable = more consistent, less variation")
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Similarity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Similarity")
                                .font(theme.font(15, weight: .medium))
                            Spacer()
                            Text(String(format: "%.2f", voice.settings.similarityBoost))
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Higher = closer to original voice characteristics")
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Supporting Views

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(theme.font(15, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : theme.accentPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? theme.accentPrimary : theme.accentTint)
            .cornerRadius(12)
        }
    }
}

struct PresetCard: View {
    let preset: VoicePreset
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
                    Text(preset.name)
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(preset.description)
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

struct VoiceCard: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let action: () -> Void
    let onPreview: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 12) {
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
                        Text(voice.name)
                            .font(theme.font(15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(voice.category)
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            if voice.previewURL != nil {
                Button(action: onPreview) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .padding(12)
        .background(isSelected ? theme.accentTint : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
final class VoiceSelectionViewModel: ObservableObject {
    @Published var voices: [ElevenLabsVoice] = []
    @Published var presets: [VoicePreset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectionMode: VoiceSelectionMode = .preset
    
    private let apiClient: SimonAPI
    private var audioPlayer: AVPlayer?
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    func loadVoices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load voices and presets in parallel
            async let voicesTask = apiClient.getVoices()
            async let presetsTask = apiClient.getVoicePresets()
            
            let (fetchedVoices, fetchedPresets) = try await (voicesTask, presetsTask)
            
            voices = fetchedVoices
            presets = fetchedPresets
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func previewVoice(_ voice: ElevenLabsVoice) {
        guard let previewURL = voice.previewURL,
              let url = URL(string: previewURL) else {
            return
        }
        
        // Stop current playback
        audioPlayer?.pause()
        
        // Play preview
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
    }
}
