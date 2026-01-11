import SwiftUI

struct RingDeviceDetailView: View {
    let ringDevice: RingDevice
    let isCoordinator: Bool
    
    var body: some View {
        Form {
            Section("Device Info") {
                LabeledContent("Name", value: ringDevice.device.name)
                LabeledContent("Role", value: isCoordinator ? "Coordinator" : "Follower")
                LabeledContent("Rank", value: "\(ringDevice.rank)")
            }

            Section("Hardware Profile") {
                if let hardwareProfile = ringDevice.device.hardwareProfile {
                    LabeledContent("Type", value: hardwareProfile.idiom.rawValue)
                    LabeledContent("Total RAM", value: hardwareProfile.totalRAM.formattedMemory)
                    LabeledContent("Recommended RAM Usage", value: hardwareProfile.recommendedUsageRAM.formattedMemory)
                }
                else {
                    Text("No hardware profile available")
                }
            }
        }
        .navigationTitle(ringDevice.device.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    let profile = HardwareProfile(
        totalRAM: 16 * 1024 * 1024 * 1024,
        recommendedUsageRAM: 8 * 1024 * 1024 * 1024,
        idiom: .mac
    )
    let discDevice = DiscoveredDevice(
        name: "Preview Device",
        host: "local",
        hardwareProfile: profile
    )
    let ringDevice = RingDevice(
        device: discDevice,
        rank: 0
    )

    NavigationStack {
        RingDeviceDetailView(ringDevice: ringDevice, isCoordinator: true)
    }
}
