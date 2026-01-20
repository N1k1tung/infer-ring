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
    private var peers: [DiscoveredDevice] = []
    private var allDevices: [DiscoveredDevice] = [] // discovered devices including self, sorted by id
    private var myIndex: Int = 0

    var currentRing: Ring?
    var coordinatorID: DeviceID?
    var state: CoordinatorState = .inactive
    var electionInProgress: Bool {
        state == .candidate
    }
    var isLeader: Bool {
        guard let coordinatorID, currentRing != nil else { return false }
        return localDeviceID == coordinatorID
    }
    var ringPeers: [RingDevice] {
        currentRing?.devices.filter { $0.id != localDeviceID } ?? []
    }
    var ringDevices: [RingDevice] {
        currentRing?.devices ?? [RingDevice(device: localDevice, rank: 0)]
    }
    var myRank: Int {
        currentRing?.devices.first { $0.id == localDeviceID }?.rank ?? 0
    }
    var totalRAM: Int {
        ringDevices.compactMap { $0.device.hardwareProfile?.totalRAM }.reduce(0, +)
    }
    var usableRAM: Int {
        ringDevices.compactMap { $0.device.hardwareProfile?.recommendedUsageRAM }.reduce(0, +)
    }

    // Local identity
    private let localDeviceID: DeviceID
    private let localDevice: DiscoveredDevice
    private let mlxManager = MLXManager()
    private let hardwareMonitor = HardwareMonitor()

    @ObservationIgnored
    private var mlxInitTask: Task<Void, Error>?

    init() {
        self.localDeviceID = DeviceID(
            name: ServiceInfo.bonjourName
        )
        self.localDevice = DiscoveredDevice(name: localDeviceID.name, host: "0.0.0.0", hardwareProfile: hardwareMonitor.currentProfile)
        self.allDevices = [localDevice]

        DI.register(mlxManager)
        DI.register(hardwareMonitor)
    }

    // MARK: - Public API

    func start() {
        Task {
            for await nodes in Observations({ [weak self] in
                self?.bonjourClient?.nodes ?? []
            }) {
                updatePeers(nodes: nodes)
            }
        }
        bonjourClient?.startSearching()
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

        guard peers != currentDiscovered else { return }
        peers = currentDiscovered
        allDevices = (peers + [localDevice]).sorted { $0.deviceID < $1.deviceID }
        myIndex = allDevices.firstIndex { $0.id == localDeviceID } ?? 0

        if !peers.isEmpty && currentRing == nil && state == .inactive {
            initiateElection()
        }
    }

    private func initiateElection() {
        dprint("Starting Election from \(localDeviceID.name)")
        state = .candidate
        let message = ElectionMessage(
            type: .election,
            candidateID: localDeviceID,
            hardwareProfile: hardwareMonitor.currentProfile,
            timestamp: Date()
        )
        sendToSuccessor(message)
    }

    func startFormation() {
        bonjourClient?.startSearching()
        initiateElection()
    }

    func stopFormation() {
        mlxInitTask?.cancel()
        currentRing = nil
        state = .inactive
        bonjourClient?.stopSearching()
    }

    private func processElectionMessage(_ message: ElectionMessage) async {
        dprint("Processing election message: \(message.type)")

        if message.candidateID != localDeviceID,
           let index = allDevices.firstIndex(where: { $0.deviceID == message.candidateID }),
           allDevices[index].hardwareProfile == nil {
            allDevices[index].hardwareProfile = message.hardwareProfile
        }

        switch message.type {
        case .election:
            if hardwareMonitor.currentProfile < message.hardwareProfile  {
                mlxInitTask?.cancel()
                state = .follower
                sendToSuccessor(message)
            }
            else if message.candidateID != localDeviceID {
                if state != .candidate {
                    // Start our own election to overtake if it's not yet in progress
                    mlxInitTask?.cancel()
                    initiateElection()
                }
            }
            else {
                // candidateID == localDeviceID
                // Our message came back! We won.
                becomeCoordinator()
            }

        case .coordinator:
            coordinatorID = message.candidateID
            state = (message.candidateID == localDeviceID) ? .coordinator : .follower
            buildRing()

            if message.candidateID != localDeviceID {
                sendToSuccessor(message)
            }
            else {
                dprint("Coordinator announcement returned to leader. Ring stable.")
            }

            mlxInitTask = Task {
                await requestMissingProfiles()
                // wait for other devices to join before initalizing MLX ring
                try await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                try mlxManager.initMLX(rank: myRank, devices: ringDevices.map { $0.device.host })
                try await Task.sleep(nanoseconds: 500_000_000)
                mlxManager.synchronize()
                dprint("MLX ring started")
                bonjourClient?.stopSearching()
            }
        }
    }

    private func buildRing() {
        guard let coordinatorID,
              let coordIndex = allDevices.firstIndex(where: { $0.deviceID == coordinatorID }) else { return }
        let orderedDevices = Array(allDevices[coordIndex...]) + Array(allDevices[..<coordIndex])

        currentRing = Ring(
            devices: orderedDevices.enumerated().map { RingDevice(device: $0.element, rank: $0.offset) },
            coordinator: coordinatorID
        )
    }

    private func becomeCoordinator() {
        dprint("I am the Coordinator!")
        coordinatorID = localDeviceID
        state = .coordinator

        let message = ElectionMessage(
            type: .coordinator,
            candidateID: localDeviceID,
            hardwareProfile: hardwareMonitor.currentProfile,
            timestamp: Date()
        )
        sendToSuccessor(message)
    }

    private func sendToSuccessor(_ message: ElectionMessage) {
        Task {
            var attempts = 4
            var successor = getSuccessor()
            while successor == nil && attempts > 0 {
                attempts -= 1
                try await Task.sleep(nanoseconds: 1_000_000_000)
                successor = getSuccessor()
            }
            guard let successor else {
                dprint("No successor to send to.")
                state = .inactive
                return
            }

            dprint("Sending to successor: \(successor.name) (\(successor.host))")

            let client = DataClient.client(for: successor)

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

    private func requestMissingProfiles() async {
        var updated = false
        for index in allDevices.indices {
            let device = allDevices[index]
            if device.id != localDeviceID && device.hardwareProfile == nil {
                let client = DataClient.client(for: device)
                if let response = await client.getHardwareProfile(request: .init(timestamp: Date())) {
                    allDevices[index].hardwareProfile = response.hardwareProfile
                    updated = true
                }
            }
        }

        if updated {
            buildRing()
        }
    }

}
