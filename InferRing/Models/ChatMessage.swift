//
import Foundation
import MLXLMCommon

struct ChatImageAttachment: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let url: URL
    let filename: String

    init(id: UUID = UUID(), url: URL, filename: String? = nil) {
        self.id = id
        self.url = url
        let resolvedFilename = filename ?? {
            let lastPathComponent = url.lastPathComponent
            return lastPathComponent.isEmpty ? url.absoluteString : lastPathComponent
        }()
        self.filename = resolvedFilename
    }

    var userInputImage: UserInput.Image {
        .url(url)
    }
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable, Codable { case user, assistant, system, tool }
    let id: UUID
    let role: Role
    var content: String
    var images: [ChatImageAttachment]

    init(id: UUID = UUID(), role: Role, content: String, images: [ChatImageAttachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
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
