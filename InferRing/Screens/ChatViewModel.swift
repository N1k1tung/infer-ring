import Foundation
import Observation
import Ring

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable { case user, assistant, system }
    let id: UUID
    let role: Role
    let content: String
    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: "You are a helpful assistant.")
    ]
    var input: String = ""
    var isSending: Bool = false
    var selectedModel: ModelCard? {
        didSet {
            guard let selectedModel else { return }
            // TODO: check mem
            Task {
                do {
                    try await mlxManager?.loadModel(selectedModel) { [weak self] progress in
                        Task { @MainActor in
                            self?.loadingProgress = progress
                        }
                    }
                }
                catch {
                    dprint(error)
                    errorMessage = "Failed to load model"
                }
            }
        }
    }
    var isShowingModelPicker: Bool = false
    var errorMessage: String? = nil
    var loadingProgress: Progress? = nil

    @ObservationIgnored
    @Inject
    private var mlxManager: MLXManager?

    func send() async throws {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        messages.append(userMessage)
        input = ""

        try await Task.sleep(nanoseconds: 600_000_000)

        let assistantReply = "You said: \(trimmedInput)"
        let assistantMessage = ChatMessage(role: .assistant, content: assistantReply)
        messages.append(assistantMessage)
    }

    func reset() {
        messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant.")
        ]
        input = ""
        isSending = false
    }
}
