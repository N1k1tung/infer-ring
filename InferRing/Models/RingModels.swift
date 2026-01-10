import Foundation

// MARK: - Device identification and capabilities
struct DeviceID: Hashable, Codable, Identifiable {
    var id: String { name }
    let name: String
    
    static func < (lhs: DeviceID, rhs: DeviceID) -> Bool {
        return lhs.id < rhs.id
    }
}

struct HardwareProfile: Codable, Equatable {
    let totalRAM: Int
    let recommendedUsageRAM: Int
    let hasNeuralAcceleration: Bool

    static func<=(lhs: HardwareProfile, rhs: HardwareProfile) -> Bool {
        lhs < rhs || lhs == rhs
    }

    static func<(lhs: HardwareProfile, rhs: HardwareProfile) -> Bool {
        // weighted comparison
        lhs.recommendedUsageRAM * 3 + lhs.totalRAM * 2 < rhs.recommendedUsageRAM * 3 + rhs.totalRAM * 2
    }
}

struct DiscoveredDevice: Identifiable, Equatable {
    var id: DeviceID { deviceID }
    let name: String
    let host: String
    var hardwareProfile: HardwareProfile?

    var deviceID: DeviceID {
        DeviceID(name: name)
    }
}

struct RingDevice: Identifiable {
    var id: DeviceID { device.id }
    let device: DiscoveredDevice
    let rank: Int

    var client: DataClient {
        .client(for: device)
    }
}

struct Ring {
    let devices: [RingDevice]
    let coordinator: DeviceID
}

enum CoordinatorState {
    case inactive
    case candidate
    case coordinator
    case follower
}
