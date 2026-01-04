import Foundation
import Observation
import Ring

@Observable
final class RingCoordinator {

    // MARK: - Dependencies
    @ObservationIgnored
    @Inject
    private var bonjourClient: BonjourClient?

    // MARK: - State
    var currentRing: Ring?
    var peers: [DiscoveredDevice] = []
    var allDevices: [DiscoveredDevice] = [] // peers including self, sorted
    var myIndex: Int = 0
    var coordinatorID: DeviceID?
    var state: CoordinatorState = .inactive
    var electionInProgress: Bool {
        state == .candidate
    }
    var isLeader: Bool {
        guard let coordinatorID, currentRing != nil else { return false }
        return localDeviceID == coordinatorID
    }

    // Local identity
    private let localDeviceID: DeviceID
    private let localDevice: DiscoveredDevice
    private let mlxManager = MLXManager()

    init() {
        self.localDeviceID = DeviceID(
            name: ServiceInfo.bonjourName
        )
        self.localDevice = DiscoveredDevice(name: localDeviceID.name, host: "0.0.0.0", hardwareProfile: nil)

        self.peers = []
        DI.register(mlxManager)
    }
    
    // MARK: - Public API
    
    func start() {
        bonjourClient?.startSearching()
        Task {
            for await nodes in Observations({ [weak self] in
                self?.bonjourClient?.nodes ?? []
            }) {
                updatePeers(nodes: nodes)
            }
        }
    }

    func handleElectionRequest(_ message: ElectionMessage) {
        Task {
            await processElectionMessage(message)
        }
    }
    
    // MARK: - Internal Logic

    private func updatePeers(nodes: [Node]) {
        let currentDiscovered = nodes.map { node -> DiscoveredDevice in
            return DiscoveredDevice(
                name: node.name,
                host: node.host,
                hardwareProfile: nil
            )
        }
        
        peers = currentDiscovered
        allDevices = (peers + [localDevice]).sorted { $0.deviceID < $1.deviceID }
        myIndex = allDevices.firstIndex { $0.id == localDeviceID } ?? 0

        // Check if we need to start election (e.g. if we have no coordinator)
        if peers.isEmpty && coordinatorID != localDeviceID {
            coordinatorID = localDeviceID
            state = .coordinator
        }
        else if !peers.isEmpty && currentRing == nil {
            initiateElection()
        }
    }
    
    private func initiateElection() {
        dprint("Starting Election from \(localDeviceID.name)")
        state = .candidate
        let message = ElectionMessage(
            type: .election(localDeviceID),
            candidateID: localDeviceID,
            timestamp: Date()
        )
        sendToSuccessor(message)
    }

    func startFormation() {
        bonjourClient?.startSearching()
        initiateElection()
    }

    func stopFormation() {
        currentRing = nil
        state = .inactive
        bonjourClient?.stopSearching()
    }

    private func processElectionMessage(_ message: ElectionMessage) async {
        dprint("Processing election message: \(message.type)")
        
        switch message.type {
        case .election(let candidateID):
            if localDeviceID < candidateID  {
                // Candidate is higher ID, so they win over us. Forward.
                state = .follower
                sendToSuccessor(message)
            }
            else if candidateID < localDeviceID {
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
            bonjourClient?.stopSearching()
            currentRing = Ring(
                devices: allDevices.enumerated().map { RingDevice(device: $0.element, rank: $0.offset) },
                coordinator: leaderID
            )

            do {
                try mlxManager.initMLX(rank: myIndex, devices: allDevices.map { $0.host })
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    mlxManager.synchronize()
                    dprint("MLX ring started")
                }
            } catch {
                dprint(error)
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
        let nextIndex = (myIndex + 1) % allDevices.count
        let successor = allDevices[nextIndex]

        if successor.id == localDeviceID {
            return nil // Ring of one
        }
        return successor
    }

}
