import SwiftUI
import Observation
import Ring

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onChange(of: viewModel.messages) { _, _ in
                    if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            
            Divider()
            messageContainer
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem {
                Button("Reset") { viewModel.reset() }
                    .disabled(viewModel.isSending)
            }
        }
        .sheet(isPresented: $viewModel.isShowingModelPicker) {
            ModelPickerView(selectedModel: $viewModel.selectedModel)
                .frame(minHeight: 560)
        }
        .errorAlert($viewModel.errorMessage)
    }

    @ViewBuilder
    private var messageContainer: some View {
        ZStack {
            VStack(spacing: 4) {
                TextField("Message", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .disabled(viewModel.isSending)

                HStack {
                    Spacer()
                    if let loadingPercent = viewModel.loadingPercent {
                        ProgressView(value: loadingPercent)
                            .progressViewStyle(.circular)
                    }
                    Button {
                        viewModel.isShowingModelPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedModel?.metadata.prettyName ?? "Select model")
                            Image(systemName: "chevron.down")
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { try? await viewModel.send() }
                    } label: {
                        if viewModel.isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSending || viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .frame(maxHeight: 30)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
            )
        }
        .padding(8)
        .background(.bar)
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
