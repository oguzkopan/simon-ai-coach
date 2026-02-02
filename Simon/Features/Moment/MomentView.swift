import SwiftUI
import PhotosUI

struct MomentView: View {
    @StateObject private var vm: MomentViewModel
    @EnvironmentObject private var theme: ThemeStore
    @FocusState private var isTextFieldFocused: Bool
    
    init(vm: MomentViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's on your mind?")
                            .font(theme.font(28, weight: .bold))
                        
                        Text("Vent, brainstorm, or ask for guidance.")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Freeform Input with Voice/Attachment
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            // Text Input Area
                            ZStack(alignment: .topLeading) {
                                if vm.freeformInput.isEmpty {
                                    Text("What's on your mind? Vent, brainstorm, or ask for guidance.")
                                        .font(theme.font(15))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $vm.freeformInput)
                                    .font(theme.font(15))
                                    .frame(minHeight: 120)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .scrollContentBackground(.hidden)
                                    .focused($isTextFieldFocused)
                            }
                            .background(Color(.systemBackground))
                            
                            // Attached Files Preview
                            if !vm.attachedFiles.isEmpty {
                                Divider()
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(vm.attachedFiles) { file in
                                            AttachmentPreview(file: file) {
                                                vm.removeAttachment(file)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                            }
                            
                            Divider()
                            
                            // Bottom Bar with Voice, Attachment, and Send Button
                            HStack(spacing: 16) {
                                // Voice Button
                                Button(action: { vm.toggleVoiceInput() }) {
                                    Image(systemName: vm.isRecording ? "mic.fill" : "mic")
                                        .font(.system(size: 20))
                                        .foregroundColor(vm.isRecording ? .red : .secondary)
                                        .frame(width: 44, height: 44)
                                }
                                
                                // Attachment Button
                                PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                        .frame(width: 44, height: 44)
                                }
                                .onChange(of: vm.selectedPhotoItem) { _, _ in
                                    vm.handlePhotoSelection()
                                }
                                
                                Spacer()
                                
                                // Send Button
                                Button(action: { 
                                    isTextFieldFocused = false
                                    vm.startFreeform()
                                }) {
                                    HStack(spacing: 6) {
                                        if vm.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        (!vm.freeformInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isLoading) 
                                            ? theme.accentPrimary 
                                            : Color.secondary.opacity(0.3)
                                    )
                                    .clipShape(Circle())
                                }
                                .disabled(vm.freeformInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // Routines Section
                    if !vm.routines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ROUTINES")
                                    .font(theme.font(13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                                
                                Spacer()
                                
                                if vm.pendingRoutinesCount > 0 {
                                    Text("\(vm.pendingRoutinesCount) Pending")
                                        .font(theme.font(13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(spacing: 12) {
                                ForEach(vm.routines) { routine in
                                    RoutineCard(routine: routine) {
                                        isTextFieldFocused = false
                                        vm.openRoutine(routine)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                        
                        Text("or")
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    
                    // Templates
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick templates")
                            .font(theme.font(17, weight: .semibold))
                            .padding(.horizontal, 16)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(vm.templates) { template in
                                TemplateCard(
                                    template: template,
                                    isLoading: vm.isLoading && vm.selectedTemplate?.id == template.id
                                ) {
                                    isTextFieldFocused = false
                                    vm.startTemplate(template)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Error message
                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .font(theme.font(13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                    
                    // Usage info
                    if !vm.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                            
                            Text("\(vm.remainingMoments) moments left today")
                                .font(theme.font(13))
                            
                            Spacer()
                            
                            Button("Upgrade") {
                                vm.showPaywall = true
                            }
                            .font(theme.font(13, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                        }
                        .padding(12)
                        .background(theme.accentTint)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Moment")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isTextFieldFocused = false
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .sheet(item: $vm.selectedRoutine) { routine in
            SystemDetailView(system: routine)
        }
        .navigationDestination(isPresented: $vm.navigateToChat) {
            if let sessionId = vm.createdSessionId,
               let coachName = vm.createdCoachName {
                ChatView(viewModel: vm.createChatViewModel(sessionId: sessionId, coachName: coachName))
            }
        }
        .task {
            await vm.loadRemainingMoments()
            await vm.loadRoutines()
        }
    }
}

// MARK: - Routine Card
struct RoutineCard: View {
    let routine: System
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title)
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(statusText)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if needsAction {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var needsAction: Bool {
        // Check if routine needs action (e.g., not run today)
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: routine.createdAt, to: Date()).day ?? 0
        return daysSinceCreation > 0
    }
    
    private var statusText: String {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: routine.createdAt, to: Date()).day ?? 0
        
        if daysSinceCreation == 0 {
            return "Last run: Today"
        } else if daysSinceCreation == 1 {
            return "Action Required"
        } else {
            return "Last run: \(daysSinceCreation)d ago"
        }
    }
}

struct TemplateCard: View {
    let template: MomentTemplate
    let isLoading: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 32, height: 32)
                
                Text(template.title)
                    .font(theme.font(15, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(template.description)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accentPrimary))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Attachment Preview
struct AttachmentPreview: View {
    let file: AttachedFile
    let onRemove: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Preview
            if file.type == .image, let uiImage = UIImage(data: file.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .offset(x: 6, y: -6)
        }
    }
}
