//

import Foundation
import Ring

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
    let timestamp: Date
}

struct GenerationResponse: Codable {
    let requestID: String
    let success: Bool
    let errorMessage: String?
    let timestamp: Date
}
