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
    let tools: [OpenAPITool]?
    let toolChoice: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, tools
        case toolChoice = "tool_choice"
    }
}

extension OpenAPIChatCompletionRequest {
    var selectedTools: [OpenAPITool]? {
        guard let tools else { return nil }
        guard let toolChoice else { return tools }

        switch toolChoice.value {
        case let choice as String:
            return choice == "none" ? nil : tools
        case let choice as [String: Any]:
            guard
                let type = choice["type"] as? String,
                type == "function",
                let function = choice["function"] as? [String: Any],
                let name = function["name"] as? String
            else {
                return tools
            }

            let filteredTools = tools.filter { $0.function.name == name }
            return filteredTools.isEmpty ? tools : filteredTools
        default:
            return tools
        }
    }
}

struct OpenAPITool: Codable {
    let type: String
    let function: OpenAPIFunction
}

struct OpenAPIFunction: Codable {
    let name: String
    let description: String?
    let parameters: [String: AnyCodable]?
}

struct OpenAPIMessage: Codable {
    let role: ChatMessage.Role
    let content: OpenAPIMessageContent?
    let name: String?
    let toolCalls: [OpenAPIToolCall]?
    let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role, content, name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

struct OpenAPIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAPIFunctionCall
}

struct OpenAPIFunctionCall: Codable {
    let name: String
    let arguments: String
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

    var imageURLs: [URL] {
        switch self {
        case .text:
            return []
        case .parts(let parts):
            return parts.compactMap(\.resolvedImageURL)
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
    let type: String
    let text: String?
    let imageURL: OpenAPIImageURL?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    var resolvedImageURL: URL? {
        guard type == "image_url",
              let rawURL = imageURL?.url else { return nil }
        return URL(string: rawURL)
    }
}

struct OpenAPIImageURL: Codable {
    let url: String
    let detail: String?
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
    let toolCalls: [OpenAPIToolCallDelta]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

struct OpenAPIToolCallDelta: Codable {
    let index: Int
    let id: String?
    let type: String?
    let function: OpenAPIFunctionCallDelta?
}

struct OpenAPIFunctionCallDelta: Codable {
    let name: String?
    let arguments: String?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}
