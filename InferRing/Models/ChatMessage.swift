//
import Foundation

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
