//
import Foundation
import MLXLMCommon

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable, Codable { case user, assistant, system, tool }
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

extension Chat.Message.Role {
    var toRole: ChatMessage.Role {
        .init(rawValue: rawValue)!
    }
}

extension ChatMessage.Role {
    var toRole: Chat.Message.Role {
        .init(rawValue: rawValue)!
    }
}
