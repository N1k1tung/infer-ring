import Foundation
import Observation
import Ring

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable { case user, assistant, system }
    let id: UUID
    let role: Role
    var content: String
    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    static let systemMessage = ChatMessage(role: .system, content: "You are a helpful assistant.")
}

@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMessage] = [.systemMessage]
    var input: String = ""
    var isSending: Bool = false
    var selectedModel: ModelCard? {
        didSet {
            guard let selectedModel,
                  selectedModel != oldValue,
                  selectedModel != modelManager?.currentModelCard
            else { return }

            Task {
                do {
                    try await modelManager?.loadModelAcrossPeers(selectedModel) { [weak self] progress in
                        Task { @MainActor in
                            self?.loadingPercent = progress
                        }
                    }
                    loadingPercent = nil
                }
                catch {
                    dprint(error)
                    errorMessage = "Failed to load model: \(error.localizedDescription)"
                    loadingPercent = nil
                    self.selectedModel = oldValue
                }
            }
        }
    }
    var canSend: Bool {
        selectedModel != nil && !isSending && !input.trimmed.isEmpty
    }
    var isShowingModelPicker: Bool = false
    var isShowingToast: Bool = false

    var errorMessage: String? = nil
    var loadingPercent: Double? = nil
    var tokensPerSecond: Double? = nil

    @ObservationIgnored
    @Inject
    private var modelManager: ModelManager?
    
    init() {
        selectedModel = modelManager?.currentModelCard

        Task { @MainActor in
            for await loadedModel in Observations({ [weak self] in
                self?.modelManager?.currentModelCard
            }) {
                selectedModel = loadedModel
                resetChat()
            }
        }
    }

    func send() async throws {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty,
              !isSending,
              let modelManager
            else { return }
        isSending = true
        defer { isSending = false }

        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        messages.append(userMessage)
        input = ""

        let assistantMessage = ChatMessage(role: .assistant, content: "...")
        messages.append(assistantMessage)
        let index = messages.count - 1
        var fullReply = ""
        for try await replyStream in modelManager.streamResponse(to: trimmedInput) {
            fullReply += replyStream
            // TODO: optimize for UI
            messages[index].content = fullReply
        }
        tokensPerSecond = modelManager.tokensPerSecond
    }

    func reset() {
        resetChat()
        modelManager?.resetChatSession()
    }

    private func resetChat() {
        messages = [.systemMessage]
        input = ""
        isSending = false
    }
}
