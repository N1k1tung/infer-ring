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
                    LabeledContent("Total RAM", value: ByteCountFormatter.string(fromByteCount: Int64(hardwareProfile.totalRAM), countStyle: .memory))
                    LabeledContent("Available RAM", value: ByteCountFormatter.string(fromByteCount: Int64(hardwareProfile.availableRAM), countStyle: .memory))
                    LabeledContent("CPU Cores", value: "\(hardwareProfile.cpuCores)")
                    LabeledContent("Neural Engine", value: hardwareProfile.hasNeuralEngine ? "Yes" : "No")
                    if let gpuMem = hardwareProfile.gpuMemory {
                        LabeledContent("GPU Memory", value: ByteCountFormatter.string(fromByteCount: Int64(gpuMem), countStyle: .memory))
                    }
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
        availableRAM: 8 * 1024 * 1024 * 1024,
        cpuCores: 8,
        hasNeuralEngine: true,
        gpuMemory: nil
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
