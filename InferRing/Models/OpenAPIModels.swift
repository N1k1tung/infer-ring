//
import Foundation

struct OpenAPIModelResponse: Codable {
    let object: String
    let data: [OpenAPIModel]
}
struct OpenAPIModel: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, ownedBy = "owned_by"
    }
}

struct OpenAPIChatCompletionRequest: Codable {
    let model: String?
    let messages: [OpenAPIMessage]
    let stream: Bool?
}

struct OpenAPIMessage: Codable {
    let role: ChatMessage.Role
    let content: OpenAPIMessageContent?
}

enum OpenAPIMessageContent: Codable {
    case text(String)
    case parts([OpenAPIMessageContentPart])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        }
        else if let parts = try? container.decode([OpenAPIMessageContentPart].self) {
            self = .parts(parts)
        }
        else {
            throw DecodingError.typeMismatch(OpenAPIMessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong format for OpenAPIMessageContent"))
        }
    }

    var text: String {
        switch self {
            case .text(let text):
            return text
        case .parts(let parts):
            return parts.compactMap { $0.type == "text" ? $0.text : nil }.joined()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

struct OpenAPIMessageContentPart: Codable {
    let text: String
    let type: String
}

struct OpenAPIChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAPIChoiceFull]
}

struct OpenAPIChoiceFull: Codable {
    let index: Int
    let message: OpenAPIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message, finishReason = "finish_reason"
    }
}

struct OpenAPIChatCompletionChunk: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAPIChoice]
}

struct OpenAPIChoice: Codable {
    let index: Int
    let delta: OpenAPIDelta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta, finishReason = "finish_reason"
    }
}

struct OpenAPIDelta: Codable {
    let role: ChatMessage.Role?
    let content: String?
}
