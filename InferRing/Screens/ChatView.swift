import SwiftUI
import Observation

struct ChatView: View {
    @State private var model = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onChange(of: model.messages) { _, _ in
                    if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            
            Divider()
            
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $model.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(model.isSending)
                
                Button {
                    Task { try? await model.send() }
                } label: {
                    if model.isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isSending || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem {
                Button("Reset") { model.reset() }
                    .disabled(model.isSending)
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .assistant || message.role == .system {
                bubble
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
                bubble
            }
        }
    }
    
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.role == .system {
                Text("System")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(message.content)
                .foregroundStyle(message.role == .system ? .secondary : .primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.15)
        case .assistant:
            return Color.gray.opacity(0.15)
        case .system:
            return Color.secondary.opacity(0.1)
        }
    }
}

#Preview {
    NavigationStack { ChatView() }
}
