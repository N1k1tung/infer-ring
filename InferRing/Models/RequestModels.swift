//

import Foundation
import Ring
import MLXLMCommon

struct Ping: Codable {
    let isAlive: Bool
}

struct ElectionMessage: Codable {
    let type: ElectionMessageType
    let candidateID: DeviceID
    let hardwareProfile: HardwareProfile
    let timestamp: Date
}

enum ElectionMessageType: Codable {
    case election
    case coordinator
}

struct ModelLoadRequest: Codable {
    let modelCard: ModelCard
    let availableFiles: [String]
    let shardMeta: ShardMetadata
    let requestID: String
    let timestamp: Date
}

struct ModelLoadResponse: Codable {
    let requestID: String
    let success: Bool
    let errorMessage: String?
    let timestamp: Date
}

struct GenerationRequest: Codable {
    let requestID: String
    let input: String
    let inputRole: ChatMessage.Role
    let history: [OpenAPIMessage]?
    let tools: [OpenAPITool]?
    let options: ChatGenerationOptions
    let timestamp: Date
}

struct GenerationResponse: Codable {
    let requestID: String
    let success: Bool
    let errorMessage: String?
    let timestamp: Date
}

struct ChatResetRequest: Codable {
    let requestID: String
    let timestamp: Date
}

struct ChatResetResponse: Codable {
    let requestID: String
    let success: Bool
    let errorMessage: String?
    let timestamp: Date
}

struct HardwareProfileRequest: Codable {
    let timestamp: Date
}

struct HardwareProfileResponse: Codable {
    let hardwareProfile: HardwareProfile
    let timestamp: Date
}

struct ChatGenerationOptions: Codable, Equatable, Sendable {
    enum KVBitsOption: String, CaseIterable, Codable, Identifiable, Sendable {
        case full
        case fourBit
        case eightBit
        case turboThreePointFive
        case turboTwoPointFive

        var id: Self { self }

        var displayName: String {
            switch self {
            case .full:
                return "Full"
            case .fourBit:
                return "4-bit"
            case .eightBit:
                return "8-bit"
            case .turboThreePointFive:
                return "3.5-bit (Turbo)"
            case .turboTwoPointFive:
                return "2.5-bit (Turbo)"
            }
        }

        var bits: Float? {
            switch self {
            case .full:
                return nil
            case .fourBit:
                return 4
            case .eightBit:
                return 8
            case .turboThreePointFive:
                return 3.5
            case .turboTwoPointFive:
                return 2.5
            }
        }
    }

    static let defaults = ChatGenerationOptions()

    var temperature: Double
    var topK: Int
    var topP: Double
    var minP: Double
    var repetitionPenalty: Double?
    var kvBits: KVBitsOption

    init(
        temperature: Double = 0.6,
        topK: Int = 0,
        topP: Double = 1.0,
        minP: Double = 0.0,
        repetitionPenalty: Double? = nil,
        kvBits: KVBitsOption = .full
    ) {
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.minP = minP
        self.repetitionPenalty = repetitionPenalty
        self.kvBits = kvBits
    }

    var generateParameters: GenerateParameters {
        GenerateParameters(
            kvBits: kvBits.bits,
            temperature: Float(temperature),
            topP: Float(topP),
            topK: topK,
            minP: Float(minP),
            repetitionPenalty: repetitionPenalty.map(Float.init)
        )
    }
}
