//
import Foundation
import MLXLMCommon

struct ModelResponseToolCall: Sendable {
    let id: String
    let name: String
    let arguments: String

    var openAPIToolCall: OpenAPIToolCall {
        OpenAPIToolCall(
            id: id,
            type: "function",
            function: OpenAPIFunctionCall(name: name, arguments: arguments)
        )
    }

    func delta(index: Int) -> OpenAPIToolCallDelta {
        OpenAPIToolCallDelta(
            index: index,
            id: id,
            type: "function",
            function: OpenAPIFunctionCallDelta(name: name, arguments: arguments)
        )
    }
}

enum ModelResponseChunk: Sendable {
    case text(String)
    case toolCall(ModelResponseToolCall)
}

extension ToolCall {
    var modelResponseToolCall: ModelResponseToolCall {
        let argumentsData = (try? JSONEncoder().encode(function.arguments)) ?? Data("{}".utf8)
        let arguments = String(data: argumentsData, encoding: .utf8) ?? "{}"
        return ModelResponseToolCall(
            id: "call_\(UUID().uuidString)",
            name: function.name,
            arguments: arguments
        )
    }
}
