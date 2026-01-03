//

import Foundation

struct Ping: Codable {
    let isAlive: Bool
}

struct ElectionMessage: Codable {
    let type: ElectionMessageType
    let candidateID: DeviceID
    let timestamp: Date
}

enum ElectionMessageType: Codable {
    case election(DeviceID)
    case coordinator(DeviceID)
}
