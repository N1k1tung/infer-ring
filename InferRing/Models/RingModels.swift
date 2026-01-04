import Foundation

// MARK: - Device identification and capabilities
struct DeviceID: Hashable, Codable, Identifiable {
    var id: UUID { uuid }
    let uuid: UUID
    let name: String
    
    static func < (lhs: DeviceID, rhs: DeviceID) -> Bool {
        return lhs.uuid.uuidString < rhs.uuid.uuidString
    }
}

struct HardwareProfile: Codable, Equatable {
    let totalRAM: UInt64
    let availableRAM: UInt64
    let cpuCores: Int
    let hasNeuralEngine: Bool
    let gpuMemory: UInt64?
}

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let host: String
    let hardwareProfile: HardwareProfile?

    var deviceID: DeviceID {
        DeviceID(uuid: id, name: name)
    }
}

struct RingDevice: Identifiable {
    var id: UUID { device.id }
    let device: DiscoveredDevice
    let rank: Int
    let predecessor: DeviceID?
    let successor: DeviceID?
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
