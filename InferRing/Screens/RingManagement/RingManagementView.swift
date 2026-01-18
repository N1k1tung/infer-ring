import SwiftUI

struct RingManagementView: View {
    @Environment(RingCoordinator.self) var coordinator
    @Environment(BonjourClient.self) var bonjourClient

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Permission check
                if bonjourClient.permissionDenied {
                    PermissionErrorBanner()
                        .padding(.horizontal)
                }

                // Topology Visualization
                RingTopologyView()
                    .frame(height: 350)
                    .padding(.top)
                
                // Status Section
                VStack(spacing: 8) {
                    Text("Ring Status")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        StatusBadge()
                        Spacer()
                        if let ring = coordinator.currentRing {
                            VStack(alignment: .leading) {
                                Text("\(ring.devices.count) Devices")
                                Text("\(coordinator.totalRAM.formattedMemory) Total RAM")
                                Text("\(coordinator.usableRAM.formattedMemory) Usable RAM")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.secondary)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Management Controls
                VStack(spacing: 16) {
                    Text("Management")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        Button {
                           startFormation()
                        } label: {
                            Label("Form Ring", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.electionInProgress)
                        
                        Button(role: .destructive) {
                            stopFormation()
                        } label: {
                            Label("Reset", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if coordinator.electionInProgress {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Election in progress...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button("Cancel") {
                                stopFormation()
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.secondary)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Instructions / Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)
                    Text("• For best performance use wired connection (such as USB-C to USB-C cable).")
                    Text("• If formation hangs, try resetting on all devices.")
                    Text("• Ensure all devices are on the same local network.")
                    Text("• Only IPv4 connections are supported.")
                    Text("• You can view accessible devices running the app in the 'Browse Devices' section.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .navigationTitle("Ring Management")
    }
    
    private func startFormation() {
        coordinator.startFormation()
    }
    
    private func stopFormation() {
        coordinator.stopFormation()
    }
}

struct StatusBadge: View {
    @Environment(RingCoordinator.self) var coordinator

    private var text: String {
        if coordinator.electionInProgress { return "Forming..." }
        if coordinator.currentRing != nil { return "Active" }
        return "Inactive"
    }

    private var color: Color {
        if coordinator.electionInProgress { return .yellow }
        if coordinator.currentRing != nil { return .green }
        return .secondary
    }

    private var icon: String {
        if coordinator.electionInProgress { return "arrow.triangle.2.circlepath" }
        if coordinator.currentRing != nil { return "checkmark.circle.fill" }
        return "circle"
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RingManagementView()
    }
}
