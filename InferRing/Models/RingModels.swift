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
    let totalRAM: UInt64
    let availableRAM: UInt64
    let cpuCores: Int
    let hasNeuralEngine: Bool
    let gpuMemory: UInt64?
}

struct DiscoveredDevice: Identifiable, Equatable {
    var id: DeviceID { deviceID }
    let name: String
    let host: String
    let hardwareProfile: HardwareProfile?

    var deviceID: DeviceID {
        DeviceID(name: name)
    }
}

struct RingDevice: Identifiable {
    var id: DeviceID { device.id }
    let device: DiscoveredDevice
    let rank: Int
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
