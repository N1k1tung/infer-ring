import SwiftUI

struct RingTopologyView: View {
    @Environment(RingCoordinator.self) var coordinator
    @State private var selectedDevice: RingDevice?
    
    var body: some View {
        VStack {
            if let ring = coordinator.currentRing, !ring.devices.isEmpty {
                RingVisualizer(ring: ring, selectedDevice: $selectedDevice)
                    .frame(minHeight: 300)
            } else {
                ContentUnavailableView(
                    "No Active Ring",
                    systemImage: "circle.slash",
                    description: Text("Start ring formation to connect devices.")
                )
            }
        }
        .sheet(item: $selectedDevice) { device in
            NavigationStack {
                RingDeviceDetailView(
                    ringDevice: device,
                    isCoordinator: device.id == coordinator.currentRing?.coordinator
                )
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #else
            .frame(minHeight: 300)
            #endif
        }
    }
}

struct RingVisualizer: View {
    let ring: Ring
    @Binding var selectedDevice: RingDevice?
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.75
            let deviceCount = ring.devices.count
            
            ZStack {
                // Connection Lines
                Path { path in
                    // Sort by rank to draw the circle correctly
                    let devices = ring.devices.sorted { $0.rank < $1.rank }
                    guard !devices.isEmpty else { return }
                    
                    for (index, _) in devices.enumerated() {
                        let angle = angle(for: index, total: deviceCount)
                        let point = pointOnCircle(center: center, radius: radius, angle: angle)
                        
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // Devices
                ForEach(ring.devices) { device in
                    let angle = angle(for: device.rank, total: deviceCount)
                    let position = pointOnCircle(center: center, radius: radius, angle: angle)
                    
                    RingDeviceNode(
                        device: device,
                        isCoordinator: device.id == ring.coordinator
                    )
                    .position(position)
                    .onTapGesture {
                        selectedDevice = device
                    }
                }
            }
        }
        .padding()
    }
    
    private func angle(for index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return (Double(index) / Double(total)) * 2 * .pi - .pi / 2
    }
    
    private func pointOnCircle(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        let x = center.x + CGFloat(cos(angle) * radius)
        let y = center.y + CGFloat(sin(angle) * radius)
        return CGPoint(x: x, y: y)
    }
}

struct RingDeviceNode: View {
    let device: RingDevice
    let isCoordinator: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        Circle()
                            .stroke(isCoordinator ? Color.orange : Color.gray.opacity(0.3), lineWidth: isCoordinator ? 2 : 1)
                    )
                    .overlay(
                        Image(systemName: device.device.hardwareProfile?.idiom.systemIcon ?? "desktopcomputer")
                            .foregroundColor(.primary)
                            .font(.system(size: 24))
                    )
                if isCoordinator {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                }
            }

            VStack(spacing: 1) {
                Text(device.device.host)
                    .font(.caption)
                    .bold()
                    .lineLimit(1)
                
                Text(isCoordinator ? "Coordinator" : "Rank \(device.rank)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .background(Color.secondary.opacity(0.8))
            .cornerRadius(4)
        }
        .frame(width: 120)
    }
}

extension DeviceIdiom {
    var systemIcon: String {
        switch self {
        case .mac: return "desktopcomputer"
        case .iPad: return "ipad"
        case .iPhone: return "iphone"
        }
    }
}

#Preview {
    let dev1 = RingDevice(
        device: DiscoveredDevice(
            name: "MacBook Pro", host: "local",
            hardwareProfile: HardwareProfile(totalRAM: 16 * 1024 * 1024 * 1024, recommendedUsageRAM: 12 * 1024 * 1024 * 1024, idiom: .mac)
        ),
        rank: 0)

    let dev2 = RingDevice(
        device: DiscoveredDevice(
            name: "iPad", host: "local",
            hardwareProfile: HardwareProfile(totalRAM: 8 * 1024 * 1024 * 1024, recommendedUsageRAM: 4 * 1024 * 1024 * 1024, idiom: .iPad)
        ),
        rank: 0)

    let dev3 = RingDevice(
        device: DiscoveredDevice(
            name: "iPhone", host: "local",
            hardwareProfile: HardwareProfile(totalRAM: 12 * 1024 * 1024 * 1024, recommendedUsageRAM: 6 * 1024 * 1024 * 1024, idiom: .iPhone)
        ),
        rank: 0)


    let ring = Ring(
        devices: [dev1, dev2, dev3],
        coordinator: dev3.device.deviceID,
    )
    
    RingVisualizer(ring: ring, selectedDevice: .constant(nil))
}
