import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var theme: ThemeStore
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    
    // Attachment Picker State
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var previewAttachment: ChatViewModel.LocalAttachment?
    @State private var showAttachmentOptions = false
    
    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        print("🟢 ChatView init - sessionID: \(viewModel.sessionID)")
    }
        
    private func savePlan(_ planInfo: PlanCardPayload.PlanInfo) async {
        let plan = Plan(
            id: UUID().uuidString,
            uid: "",
            coachId: viewModel.coachName,
            title: planInfo.title,
            objective: planInfo.objective,
            horizon: PlanHorizon(rawValue: planInfo.horizon.lowercased()) ?? .week,
            milestones: planInfo.milestones.map { milestone in
                Milestone(
                    id: UUID().uuidString,
                    title: milestone.label,
                    description: milestone.successMetric,
                    dueDate: nil,
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.isLoadingMessages {
                            // State 1: Loading messages
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Loading conversation...")
                                    .font(theme.font(15))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else if let errorMessage = viewModel.errorMessage, viewModel.shouldShowError {
                            // State 2: Error occurred (only show after delay)
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("Failed to load messages")
                                    .font(theme.font(17, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(errorMessage)
                                    .font(theme.font(14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                HStack(spacing: 12) {
                                    Button("Try Again") {
                                        Task {
                                            await viewModel.loadMessages()
                                        }
                                    }
                                    .font(theme.font(15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(theme.accentPrimary)
                                    .cornerRadius(10)
                                    
                                    if errorMessage.contains("sign in") {
                                        Button("Sign In") {
                                            // TODO: Show sign in sheet
                                            print("Show sign in")
                                        }
                                        .font(theme.font(15, weight: .semibold))
                                        .foregroundColor(theme.accentPrimary)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else if viewModel.messages.isEmpty && viewModel.hasCompletedInitialLoad {
                            // State 3: Successfully loaded but no messages yet (empty session)
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
                        } else if !viewModel.messages.isEmpty {
                            // State 4: Messages loaded successfully
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, onPin: { msg in
                                    viewModel.pinAsSystem(msg)
                                })
                                .id(message.id)
                            }
                            
                            // Display cards after messages
                            
                            // Tool request history (approved/declined items)
                            ForEach(viewModel.toolRequestHistory.filter { $0.status != .pending }) { historyItem in
                                ToolApprovalCard(
                                    toolRequest: historyItem.toolRequest,
                                    status: historyItem.status,
                                    onApprove: nil,
                                    onDecline: nil
                                )
                                .padding(.top, 8)
                                .id(historyItem.id)
                            }
                            
                            // Current pending tool approval card (interactive)
                            if let toolRequest = viewModel.toolRequest {
                                ToolApprovalCard(
                                    toolRequest: toolRequest,
                                    status: .pending,
                                    onApprove: {
                                        Task {
                                            await viewModel.approveToolExecution()
                                        }
                                    },
                                    onDecline: {
                                        viewModel.declineToolExecution()
                                    }
                                )
                                .padding(.top, 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                            
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
                    UIApplication.shared.endEditing()
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
            .onTapGesture {
                isInputFocused = false
                UIApplication.shared.endEditing()
            }
            
            if let errorMessage = viewModel.errorMessage, !viewModel.messages.isEmpty {
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
            
            // Composer Area (Sticky Bottom)
            VStack(spacing: 0) {
                Divider()
                
                VStack(spacing: 0) {
                    // Attachment Strip & Upload Indicator
                    if !viewModel.localAttachments.isEmpty || viewModel.isUploading {
                        VStack(alignment: .leading, spacing: 8) {
                            if !viewModel.localAttachments.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.localAttachments) { attachment in
                                            ZStack(alignment: .topTrailing) {
                                                Button(action: {
                                                    previewAttachment = attachment
                                                }) {
                                                    if let preview = attachment.previewImage {
                                                        Image(uiImage: preview)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 56, height: 56)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                            )
                                                    } else {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(Color.blue.opacity(0.1))
                                                            Image(systemName: "doc.fill")
                                                                .font(.system(size: 24))
                                                                .foregroundColor(.blue)
                                                        }
                                                        .frame(width: 56, height: 56)
                                                    }
                                                }
                                                
                                                // Remove Button
                                                Button(action: {
                                                    withAnimation {
                                                        viewModel.removeAttachment(id: attachment.id)
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.gray)
                                                        .background(Color.white.clipShape(Circle()))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                            .padding(.top, 6)
                                            .padding(.trailing, 6)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 78)
                            }
                            
                            if viewModel.isUploading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Uploading attachments...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Input Row
                    HStack(alignment: .bottom, spacing: 10) {
                        // Attachment Button
                        Button(action: {
                            // Logic to show action sheet or menu
                            showAttachmentOptions = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.gray)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.isStreaming)
                        .confirmationDialog("Add Attachment", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
                            Button("Photo Library") { showImagePicker = true }
                            Button("Camera") { showCamera = true }
                            Button("Document") { showDocumentPicker = true }
                            Button("Cancel", role: .cancel) { }
                        }
                        
                        // Text field
                        TextField("Message...", text: $viewModel.composerText, axis: .vertical)
                            .font(theme.font(16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .focused($isInputFocused)
                            .lineLimit(1...5)
                            .disabled(viewModel.isStreaming)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                        
                        // Send/Stop button
                        Button(action: {
                            if viewModel.isStreaming {
                                viewModel.stopStreaming()
                            } else {
                                viewModel.send()
                            }
                        }) {
                            Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(viewModel.isStreaming ? .red : (viewModel.composerText.isEmpty && viewModel.localAttachments.isEmpty ? .gray : theme.accentPrimary))
                        }
                        .disabled(!viewModel.isStreaming && viewModel.composerText.isEmpty && viewModel.localAttachments.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
            }
        } // VStack
        .navigationTitle(viewModel.coachName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            // Auto-focus the text field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }

        .task {
            print("🟢 ChatView .task triggered - sessionID: \(viewModel.sessionID)")
            AnalyticsManager.shared.logScreenView("chat", screenClass: "ChatView")
            AnalyticsManager.shared.logSessionStarted(
                coachID: viewModel.sessionCoachID ?? "unknown",
                sessionID: viewModel.sessionID
            )
            
            if viewModel.messages.isEmpty && !viewModel.isLoadingMessages {
                print("🟢 Calling loadMessages()")
                await viewModel.loadMessages()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $viewModel.selectedImage)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(fileURL: $viewModel.selectedFileURL)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $viewModel.selectedImage)
        }
        .sheet(item: $previewAttachment) { attachment in
            AttachmentPreviewView(attachment: attachment) {
                withAnimation {
                    viewModel.removeAttachment(id: attachment.id)
                }
                previewAttachment = nil
            }
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

struct AttachmentPreviewView: View {
    let attachment: ChatViewModel.LocalAttachment
    let onDelete: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = attachment.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        Text(attachment.fileExtension.uppercased())
                            .font(.title)
                            .bold()
                        Text("Document Preview Not Available")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Attachment Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Tool Approval Card (Inline)
struct ToolApprovalCard: View {
    let toolRequest: ToolRequestPayload
    let status: ChatViewModel.ToolRequestHistory.ToolApprovalStatus
    let onApprove: (() -> Void)?
    let onDecline: (() -> Void)?
    
    @EnvironmentObject private var theme: ThemeStore
    @State private var isExecuting = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: toolIcon)
                    .font(.system(size: 24))
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolTitle)
                        .font(theme.font(17, weight: .semibold))
                    Text(statusText)
                        .font(theme.font(13))
                        .foregroundColor(statusColor)
                }
                
                Spacer()
                
                // Status badge
                if status != .pending {
                    HStack(spacing: 4) {
                        Image(systemName: status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                        Text(status == .approved ? "Approved" : "Declined")
                            .font(theme.font(13, weight: .semibold))
                    }
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Preview
            toolPreview
            
            // Action Buttons (only for pending)
            if status == .pending, let onApprove = onApprove, let onDecline = onDecline {
                HStack(spacing: 12) {
                    Button(action: {
                        onDecline()
                    }) {
                        Text("Decline")
                            .font(theme.font(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .disabled(isExecuting)
                    
                    Button(action: {
                        isExecuting = true
                        onApprove()
                        // Note: isExecuting will be reset when toolRequest becomes nil
                    }) {
                        HStack {
                            if isExecuting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Approve")
                                    .font(theme.font(15, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(theme.accentPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isExecuting)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusBorderColor, lineWidth: status == .pending ? 0 : 2)
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return theme.accentPrimary
        case .approved:
            return .green
        case .declined:
            return .red
        }
    }
    
    private var statusBorderColor: Color {
        switch status {
        case .pending:
            return .clear
        case .approved:
            return .green.opacity(0.3)
        case .declined:
            return .red.opacity(0.3)
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending:
            return "Requires your approval"
        case .approved:
            return "Completed successfully"
        case .declined:
            return "You declined this action"
        }
    }
        
    private var toolIcon: String {
        switch toolRequest.toolId {
        case "local_notification_schedule":
            return "bell.fill"
        case "calendar_event_create":
            return "calendar.badge.plus"
        case "reminder_create":
            return "checklist"
        default:
            return "wrench.and.screwdriver"
        }
    }
        
    private var toolTitle: String {
        switch toolRequest.toolId {
        case "local_notification_schedule":
            return "Schedule Notification"
        case "calendar_event_create":
            return "Create Calendar Event"
        case "reminder_create":
            return "Create Reminder"
        default:
            return "Tool Execution"
        }
    }
        
    @ViewBuilder
    private var toolPreview: some View {
        let convertedInput = toolRequest.input.mapValues { $0.value }
        
        VStack(alignment: .leading, spacing: 8) {
            switch toolRequest.toolId {
            case "local_notification_schedule":
                if let title = convertedInput["title"] as? String {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(theme.font(15, weight: .medium))
                    }
                }
                
                if let body = convertedInput["body"] as? String {
                    Text(body)
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                }
                
                if let trigger = convertedInput["trigger"] as? [String: Any],
                   let fireAt = trigger["fire_at_iso"] as? String {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(formatISO8601(fireAt))
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                }
                
            case "calendar_event_create":
                if let title = convertedInput["title"] as? String {
                    Text(title)
                        .font(theme.font(15, weight: .medium))
                }
                
                if let startISO = convertedInput["start_iso"] as? String,
                   let endISO = convertedInput["end_iso"] as? String {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("\(formatISO8601(startISO)) - \(formatTime(endISO))")
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let notes = convertedInput["notes"] as? String, !notes.isEmpty {
                    Text(notes)
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
            case "reminder_create":
                if let title = convertedInput["title"] as? String {
                    Text(title)
                        .font(theme.font(15, weight: .medium))
                }
                
                if let dueISO = convertedInput["due_iso"] as? String {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Due: \(formatISO8601(dueISO))")
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                }
                
            default:
                Text("Tool: \(toolRequest.toolId)")
                    .font(theme.font(14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

private func formatISO8601(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: isoString) else {
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .short
    
    return displayFormatter.string(from: date)
}

private func formatTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: isoString) else {
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.timeStyle = .short
    
    return displayFormatter.string(from: date)
}
