import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var theme: ThemeStore
    @State private var scrollProxy: ScrollViewProxy?
    
    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, onPin: { msg in
                                viewModel.pinAsSystem(msg)
                            })
                            .id(message.id)
                        }
                    }
                    .padding(16)
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
    let onSend: () -> Void
    let onStop: () -> Void
    let onAttach: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    @FocusState private var isFocused: Bool
    
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
                .focused($isFocused)
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
