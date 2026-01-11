import Foundation
#if os(iOS)
import UIKit
#endif
// MARK: - Device identification and capabilities
struct DeviceID: Hashable, Codable, Identifiable {
    var id: String { name }
    let name: String
    
    static func < (lhs: DeviceID, rhs: DeviceID) -> Bool {
        return lhs.id < rhs.id
    }
}

enum DeviceIdiom: String, Codable, Hashable {
    case iPhone
    case iPad
    case mac

    static let current: DeviceIdiom = {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #else
        .mac
        #endif
    }()
}

struct HardwareProfile: Codable, Equatable {
    let totalRAM: Int
    let recommendedUsageRAM: Int
    let idiom: DeviceIdiom

    static func<=(lhs: HardwareProfile, rhs: HardwareProfile) -> Bool {
        lhs < rhs || lhs == rhs
    }

    static func<(lhs: HardwareProfile, rhs: HardwareProfile) -> Bool {
        lhs.recommendedUsageRAM < rhs.recommendedUsageRAM
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
