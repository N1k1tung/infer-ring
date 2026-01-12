//

import Foundation
import Ring
import MLX
import MLXLMCommon
import MLXLLM

@Observable
final class ModelManager {
    @ObservationIgnored
    @Inject
    var coordinator: RingCoordinator?
    
    @ObservationIgnored
    @Inject
    private var mlxManager: MLXManager?
    
    @ObservationIgnored
    @Inject
    private var hardwareMonitor: HardwareMonitor?
    
    // Current loaded model state
    @ObservationIgnored
    private var currentModel: ModelContext? {
        didSet {
            resetChatSession()
        }
    }
    @ObservationIgnored
    private var chatSession: ChatSession?
    var currentModelCard: ModelCard?
    var isLoading: Bool = false
    var tokensPerSecond: Double? {
        chatSession?.lastGenerationInfo?.tokensPerSecond
    }

    // MARK: - Public API

    private func checkIfCanLoad(_ modelCard: ModelCard) throws {
        let devices = coordinator?.ringDevices ?? []
        let totalMemory = devices.compactMap { $0.device.hardwareProfile?.recommendedUsageRAM }.reduce(0, +)
        if modelCard.metadata.storageSize.inBytes > totalMemory {
            throw ModelManagerError.insufficientResources("total ring memory: \(totalMemory.formattedMemory), required: \(modelCard.metadata.storageSize.inBytes.formattedMemory)")
        }
    }

    /// Load a model across all peers in the ring (only callable by leader)
    func loadModelAcrossPeers(_ modelCard: ModelCard, progressHandler: @Sendable @escaping (_ progress: Double) -> Void = { _ in }) async throws {
        guard let coordinator else {
            throw ModelManagerError.notInitialized
        }
        
        guard !isLoading else {
            throw ModelManagerError.alreadyLoading
        }

        try checkIfCanLoad(modelCard)

        isLoading = true
        var loadingProgress = 0.0
        
        defer {
            isLoading = false
        }

        let peers = coordinator.ringPeers
        var responses: [ModelLoadResponse] = []
        let requestId = UUID().uuidString
        let shardMeta = try assignShardMetadata(modelCard: modelCard)

        await withTaskGroup(of: ModelLoadResponse?.self) { group in
            group.addTask { [weak self] in
                let result = try? await self?.loadModelLocally(modelCard, shardMeta: shardMeta[coordinator.myRank]) { progress in
                    // Local loading is 50% of total
                    progressHandler(progress.fractionCompleted * 0.5)
                }
                loadingProgress += 0.5
                return result
            }
            
            for peer in peers {
                group.addTask {
                    let request = ModelLoadRequest(
                        modelCard: modelCard,
                        shardMeta: shardMeta[peer.rank],
                        requestID: requestId,
                        timestamp: Date()
                    )
                    let response = await peer.client.loadModel(request: request)
                    loadingProgress += 0.5 * (1.0 / Double(peers.count))
                    progressHandler(loadingProgress)
                    return response
                }
            }
            
            for await response in group {
                if let response {
                    responses.append(response)
                }
            }
        }
        
        // Check if all peers loaded successfully
        let failedPeers = responses.filter { !$0.success }
        if !failedPeers.isEmpty {
            let errorMessages = failedPeers.compactMap { $0.errorMessage }.joined(separator: ", ")
            throw ModelManagerError.peerLoadingFailed(errorMessages)
        }
        
        // Update state
        currentModelCard = modelCard
        Memory.clearCache()
    }


    /// stream chat response
    /// - Parameter input: user input
    /// - Returns: response stream
    func streamResponse(to input: String) -> AsyncThrowingStream<String, any Error> {
        guard let chatSession else {
            return AsyncThrowingStream { $0.finish(throwing: ModelManagerError.notInitialized) }
        }
        
        // Start generation on all peers in parallel
        let request = GenerationRequest(
            requestID: UUID().uuidString,
            input: input,
            timestamp: Date()
        )

        let peers = coordinator?.ringPeers ?? []
        let peerGenerationTask = Task {
            await withTaskGroup(of: GenerationResponse?.self) { group in
                for peer in peers {
                    group.addTask {
                        await peer.client.startGeneration(request: request)
                    }
                }
            }
        }

        let originalStream = chatSession.streamResponse(to: input)

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let task = Task {
            do {
                for try await chunk in originalStream {
                    continuation.yield(chunk)
                }
                defer { continuation.finish() }

                // Sync last message content to peers
                guard let lastMessage = chatSession.messages.last else {
                    return
                }

                let updateRequest = UpdateLastMessageRequest(
                    content: lastMessage.content,
                    timestamp: Date()
                )

                await peerGenerationTask.value
                await withTaskGroup(of: Void.self) { group in
                    for peer in peers {
                        group.addTask {
                            _ = await peer.client.updateLastMessage(request: updateRequest)
                        }
                    }
                }
            }
            catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
        return stream
    }

    /// Handle generation request from remote peer
    func handleGenerationRequest(_ request: GenerationRequest) async -> GenerationResponse {
        guard let chatSession else {
            return GenerationResponse(
                requestID: request.requestID,
                success: false,
                errorMessage: "ChatSession not initialized",
                timestamp: Date()
            )
        }
        
        do {
            let response = try await chatSession.respond(to: request.input)
            dprint(response)
            dprint(chatSession.lastGenerationInfo)
            
            return GenerationResponse(
                requestID: request.requestID,
                success: true,
                errorMessage: nil,
                timestamp: Date()
            )
        }
        catch {
            return GenerationResponse(
                requestID: request.requestID,
                success: false,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
    }

    /// starts a new chat session
    func resetChatSession() {
        guard let currentModel else { return }
        chatSession = ChatSession(currentModel, instructions: ChatMessage.systemMessage.content)
        Memory.clearCache()
    }

    /// Handle model load request from coordinator
    func handleModelLoadRequest(_ request: ModelLoadRequest) async -> ModelLoadResponse {
        do {
            _ = try await loadModelLocally(request.modelCard, shardMeta: request.shardMeta) { _ in }
            currentModelCard = request.modelCard

            return ModelLoadResponse(
                requestID: request.requestID,
                success: true,
                errorMessage: nil,
                timestamp: Date()
            )
        }
        catch {
            return ModelLoadResponse(
                requestID: request.requestID,
                success: false,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
    }
    
    /// Handle update last message request from peer
    func handleUpdateLastMessageRequest(_ request: UpdateLastMessageRequest) -> UpdateLastMessageResponse {
        guard let chatSession else {
            return UpdateLastMessageResponse(
                success: false,
                errorMessage: "ChatSession not initialized",
                timestamp: Date()
            )
        }
        
        if !chatSession.messages.isEmpty {
            let lastIndex = chatSession.messages.count - 1
            chatSession.messages[lastIndex].content = request.content
            
            return UpdateLastMessageResponse(
                success: true,
                errorMessage: nil,
                timestamp: Date()
            )
        }
        else {
            return UpdateLastMessageResponse(
                success: false,
                errorMessage: "Chat session has no messages",
                timestamp: Date()
            )
        }
    }

    // MARK: - Private Methods

    /// Load model locally using MLXManager
    private func loadModelLocally(
        _ modelCard: ModelCard,
        shardMeta: ShardMetadata,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelLoadResponse? {
        guard let mlxManager = mlxManager else {
            throw ModelManagerError.notInitialized
        }
        
        currentModel = try await mlxManager.loadModel(modelCard, shardMeta: shardMeta, progressHandler: progressHandler)
        return nil
    }
    
    /// assigns shards for ring devices per their memory % of total
    /// - Returns: shard metadatas, sorted by rank
    private func assignShardMetadata(modelCard: ModelCard) throws -> [ShardMetadata] {
        guard let coordinator else {
            throw ModelManagerError.notInitialized
        }
        let devices = coordinator.ringDevices.sorted { $0.rank < $1.rank }
        let totalMemory = devices.compactMap { $0.device.hardwareProfile?.recommendedUsageRAM }.reduce(0, +)
        var metas = [ShardMetadata]()
        var assignedLayers = 0
        let size = devices.count
        let nLayers = modelCard.metadata.nLayers
        for device in devices {
            let deviceMemory = device.device.hardwareProfile?.recommendedUsageRAM ?? 1024 * 1024 * 1024
            let shardLayers = nLayers *  deviceMemory / totalMemory
            metas.append(ShardMetadata(
                modelMeta: modelCard.metadata,
                deviceRank: device.rank,
                worldSize: size,
                startLayer: assignedLayers,
                endLayer: device.rank < size - 1 ? assignedLayers+shardLayers : nLayers,
                nLayers: nLayers
            ))
            assignedLayers += shardLayers
        }
        return metas
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case notInitialized
    case alreadyLoading
    case peerLoadingFailed(String)
    case insufficientResources(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Dependencies not initialized"
        case .alreadyLoading:
            return "Model loading is already in progress"
        case .peerLoadingFailed(let message):
            return "Failed to load model on some peers: \(message)"
        case .insufficientResources(let message):
            return "Insufficient system resources: \(message)"
        }
    }
}


