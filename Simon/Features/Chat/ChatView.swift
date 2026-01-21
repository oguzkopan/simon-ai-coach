import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var theme: ThemeStore
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    
    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Save Plan
    
    private func savePlan(_ planInfo: PlanCardPayload.PlanInfo) async {
        // Convert PlanInfo to Plan
        let plan = Plan(
            id: UUID().uuidString,
            uid: "", // Will be set by backend
            coachId: viewModel.coachName,
            title: planInfo.title,
            objective: planInfo.objective,
            horizon: PlanHorizon(rawValue: planInfo.horizon.lowercased()) ?? .week,
            milestones: planInfo.milestones.map { milestone in
                Milestone(
                    id: UUID().uuidString,
                    title: milestone.label,
                    description: milestone.successMetric,
                    dueDate: nil, // Parse from dueDateHint if needed
                    status: .pending
                )
            },
            nextActions: planInfo.nextActions.enumerated().map { index, actionTitle in
                NextAction(
                    id: "action_\(index + 1)",
                    title: actionTitle,
                    durationMin: nil,
                    energy: nil,
                    when: nil,
                    status: .pending,
                    completedAt: nil
                )
            },
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let apiClient = SimonAPIClient.shared
        do {
            _ = try await apiClient.createPlan(coachId: viewModel.coachName, plan: plan)
        } catch {
            viewModel.errorMessage = "Failed to save plan: \(error.localizedDescription)"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Start a conversation")
                                    .font(theme.font(17))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, onPin: { msg in
                                    viewModel.pinAsSystem(msg)
                                })
                                .id(message.id)
                            }
                            
                            // Display cards after messages
                            if let nextActions = viewModel.nextActionsCard {
                                NextActionsCard(
                                    items: nextActions.items,
                                    onActionComplete: { actionId in
                                        // Handle action completion
                                    },
                                    onConvertToReminder: { action in
                                        // Handle convert to reminder
                                    },
                                    onConvertToCalendar: { action in
                                        // Handle convert to calendar
                                    }
                                )
                                .padding(.top, 8)
                            }
                            
                            if let plan = viewModel.planCard {
                                PlanCard(
                                    planInfo: plan.plan,
                                    onSave: {
                                        // Handle save plan
                                        Task {
                                            await savePlan(plan.plan)
                                        }
                                    }
                                )
                                .padding(.top, 8)
                            }
                            
                            if let review = viewModel.weeklyReviewCard {
                                WeeklyReviewCard(review: WeeklyReview(
                                    wins: review.review.wins,
                                    misses: review.review.misses,
                                    rootCauses: review.review.rootCauses,
                                    nextWeekFocus: review.review.nextWeekFocus,
                                    commitments: review.review.commitments.map { Commitment(text: $0) }
                                ))
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(16)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Error banner
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(theme.font(13))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.red)
            }
            
            // Composer
            ComposerBar(
                text: $viewModel.composerText,
                isStreaming: viewModel.isStreaming,
                isFocused: $isInputFocused,
                onSend: { viewModel.send() },
                onStop: { viewModel.stopStreaming() },
                onAttach: { viewModel.showAttachmentPicker = true }
            )
            .padding(16)
        }
        .navigationTitle(viewModel.coachName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
        }
        .sheet(isPresented: $viewModel.showPinSheet) {
            if let message = viewModel.selectedMessageForPin {
                PinSystemSheet(message: message) { title, checklist, schedule, metrics in
                    await viewModel.createSystem(
                        title: title,
                        checklist: checklist,
                        schedule: schedule,
                        metrics: metrics
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showToolConfirmation) {
            if let toolRequest = viewModel.toolRequest {
                ToolConfirmationSheet(
                    toolRequest: toolRequest,
                    onApprove: {
                        await viewModel.approveToolExecution()
                    },
                    onDecline: {
                        viewModel.declineToolExecution()
                    }
                )
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let onPin: ((Message) -> Void)?
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.contentText)
                    .font(theme.font(15))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(12)
                    .background(message.isUser ? theme.accentPrimary : Color(.systemGray6))
                    .cornerRadius(16)
                
                HStack(spacing: 8) {
                    Text(message.createdAt, style: .time)
                        .font(theme.font(11))
                        .foregroundColor(.secondary)
                    
                    // Pin button for assistant messages
                    if !message.isUser, let onPin = onPin {
                        Button(action: { onPin(message) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pin")
                                Text("Pin")
                            }
                            .font(theme.font(11, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                        }
                    }
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

struct ComposerBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onStop: () -> Void
    let onAttach: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment button (Pro feature)
            Button(action: onAttach) {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 44, height: 44)
            }
            .disabled(isStreaming)
            
            // Text field
            TextField("Message...", text: $text, axis: .vertical)
                .font(theme.font(15))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .lineLimit(1...4)
                .focused(isFocused)
                .disabled(isStreaming)
            
            // Send/Stop button
            Button(action: isStreaming ? onStop : onSend) {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isStreaming ? .red : (text.isEmpty ? .gray : theme.accentPrimary))
                    .frame(width: 44, height: 44)
            }
            .disabled(!isStreaming && text.isEmpty)
        }
    }
}
