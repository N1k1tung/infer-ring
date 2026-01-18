import SwiftUI

struct RingManagementView: View {
    @Environment(RingCoordinator.self) var coordinator
    @State private var showingError = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                            Text("\(ring.devices.count) Devices")
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
                
                // Additional Info / Error Display
                if let error = errorMessage {
                    ErrorBanner(message: error) {
                        errorMessage = nil
                    }
                    .padding(.horizontal)
                }
                
                // Instructions / Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)
                    Text("• For best performance use wired connection (such as USB-C to USB-C cable).")
                    Text("• If formation hangs, try resetting on all devices.")
                    Text("• Ensure all devices are on the same local network.")
                    Text("• You can view accessible devices running the app in the 'Browse Devices' section.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .navigationTitle("Ring Management")
        .alert("Error", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }
    
    private func startFormation() {
        coordinator.startFormation()
    }
    
    private func stopFormation() {
        coordinator.stopFormation()
    }
}

struct ErrorBanner: View {
    let message: String
    private var onDismiss: (() -> Void)?
    
    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .foregroundStyle(.white)
                .font(.callout)
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.8))
        .cornerRadius(8)
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
//    let coord = RingCoordinator()
    NavigationStack {
        RingManagementView()
//            .environment(coord)
    }
}
