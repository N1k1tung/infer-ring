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
    var selectedModel: ModelCard?
    var isShowingModelPicker: Bool = false

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
