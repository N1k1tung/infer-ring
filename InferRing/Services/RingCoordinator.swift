import Foundation
import Observation
import CryptoKit

@Observable
final class RingCoordinator {

    // MARK: - Dependencies
    @ObservationIgnored
    @Inject
    private var bonjourClient: BonjourClient?

    // MARK: - State
    var currentRing: Ring?
    var peers: [DiscoveredDevice] = []
    var coordinatorID: DeviceID?
    var state: CoordinatorState = .inactive
    
    // Local identity
    let localDeviceID: DeviceID
    
    init() {
        self.localDeviceID = DeviceID(
            uuid: UUID(),
            name: ServiceInfo.bonjourName
        )
        
        self.peers = []
        start()
    }
    
    // MARK: - Public API
    
    func start() {
        bonjourClient?.startSearching()
        _ = withObservationTracking {
            bonjourClient?.nodes
        } onChange: { [weak self] in
            self?.updatePeers()
        }
    }
    
    func handleElectionRequest(_ message: ElectionMessage) {
        Task {
            await processElectionMessage(message)
        }
    }
    
    // MARK: - Internal Logic

    private func updatePeers() {
        let nodes = bonjourClient?.nodes ?? []

        // Map Nodes to DiscoveredDevices with stable UUIDs
        let currentDiscovered = nodes.map { node -> DiscoveredDevice in
            return DiscoveredDevice(
                id: UUID(),
                name: node.name,
                host: node.host,
                hardwareProfile: nil // Not needed for simple election
            )
        }
        
        // Simple diff or update
        self.peers = currentDiscovered
        
        // Check if we need to start election (e.g. if we have no coordinator)
        // Or just wait for user trigger? "Auto-election" implies automatic.
        // If we are alone, we are coordinator.
        if peers.isEmpty && coordinatorID != localDeviceID {
            coordinatorID = localDeviceID
            state = .coordinator
        }
        else if !peers.isEmpty && coordinatorID == nil {
            // New peers found, no coordinator, start election
            initiateElection()
        }
    }
    
    func initiateElection() {
        dprint("Starting Election from \(localDeviceID.name)")
        state = .candidate
        let message = ElectionMessage(
            type: .election(localDeviceID),
            candidateID: localDeviceID,
            timestamp: Date()
        )
        sendToSuccessor(message)
    }
    
    private func processElectionMessage(_ message: ElectionMessage) async {
        dprint("Processing election message: \(message.type)")
        
        switch message.type {
        case .election(let candidateID):
            if candidateID.uuid.uuidString > localDeviceID.uuid.uuidString {
                // Determine if we should forward
                // Candidate is higher ID, so they win over us. Forward.
                state = .follower
                // Update candidate in message? No, message is immutable, just forward.
                sendToSuccessor(message)
            }
            else if candidateID.uuid.uuidString < localDeviceID.uuid.uuidString {
                if state != .candidate {
                    // Start our own election to overtake
                    initiateElection()
                }
            }
            else {
                // candidateID == localDeviceID
                // Our message came back! We won.
                becomeCoordinator()
            }
            
        case .coordinator(let leaderID):
            coordinatorID = leaderID
            state = (leaderID == localDeviceID) ? .coordinator : .follower
            
            if leaderID != localDeviceID {
                sendToSuccessor(message)
            }
            else {
                dprint("Coordinator announcement returned to leader. Ring stable.")
            }
        }
    }
    
    private func becomeCoordinator() {
        dprint("I am the Coordinator!")
        coordinatorID = localDeviceID
        state = .coordinator
        
        let message = ElectionMessage(
            type: .coordinator(localDeviceID),
            candidateID: localDeviceID,
            timestamp: Date()
        )
        sendToSuccessor(message)
    }
    
    private func sendToSuccessor(_ message: ElectionMessage) {
        guard let successor = getSuccessor() else {
            dprint("No successor to send to.")
            return
        }
        
        dprint("Sending to successor: \(successor.name) (\(successor.host))")
        
        Task {
            let url = "http://\(successor.host):\(ServiceInfo.port)"
            let client = DataClient(baseUrl: url)
            
            await client.elect(message: message)
        }
    }
    
    private func getSuccessor() -> DiscoveredDevice? {
        var all = peers
        // Add self (stubbed as discovered device)
        let selfDevice = DiscoveredDevice(id: localDeviceID.uuid, name: localDeviceID.name, host: "localhost", hardwareProfile: nil)
        all.append(selfDevice)
        
        let sorted = all.sorted { $0.deviceID.uuid.uuidString < $1.deviceID.uuid.uuidString }
        
        guard let myIndex = sorted.firstIndex(where: { $0.id == localDeviceID.uuid }) else { return nil }
        
        let nextIndex = (myIndex + 1) % sorted.count
        let successor = sorted[nextIndex]
        
        if successor.id == localDeviceID.uuid {
            return nil // Ring of one
        }
        return successor
    }

}
