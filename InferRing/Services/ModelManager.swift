//

import Foundation
import Ring
import MLX
import MLXLMCommon
import MLXLLM
#if os(iOS)
import UIKit
#endif

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
    @ObservationIgnored
    private let chatHistoryStore = ChatHistoryStore()
    var currentModelCard: ModelCard?
    var isLoading: Bool = false
    var promptTokensPerSecond: Double?
    var tokensPerSecond: Double?

    func messageHistory() async -> [ChatMessage] {
        await chatHistoryStore.snapshot()
    }

    // MARK: - Public API

    private func checkIfCanLoad(_ modelCard: ModelCard) throws {
        let totalMemory = coordinator?.usableRAM ?? 0
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

        let availableFiles = await modelCard.downloadedFiles
        let localProgressMulti = !peers.isEmpty ? 0.5 : 1.0 // Local loading is 50% of total if peers present

        await withTaskGroup(of: ModelLoadResponse?.self) { group in
            group.addTask { [weak self] in
                guard let self else { return nil }
                do {
                    let result = try await loadModelLocally(modelCard, shardMeta: shardMeta[coordinator.myRank]) { progress in
                        progressHandler(progress.fractionCompleted * localProgressMulti)
                    }
                    loadingProgress += localProgressMulti
                    return result
                }
                catch {
                    return ModelLoadResponse(
                        requestID: "",
                        success: false,
                        errorMessage: error.localizedDescription,
                        timestamp: Date()
                    )
                }
            }
            
            for peer in peers {
                group.addTask {
                    let request = ModelLoadRequest(
                        modelCard: modelCard,
                        availableFiles: availableFiles,
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

    /// stream response
    /// - Parameter messages: full message history including system
    /// - Parameter tools: list of available tools
    /// - Returns: response stream
    func streamResponse(to messages: [OpenAPIMessage], tools: [OpenAPITool]? = nil) async -> AsyncThrowingStream<String, any Error> {
        var messages = messages
        
        if let tools, !tools.isEmpty {
            let toolPrompt = generateToolPrompt(tools)
            if let idx = messages.firstIndex(where: { $0.role == .system }) {
                let oldContent = messages[idx].content?.text ?? ""
                let newContent = oldContent + "\n\n" + toolPrompt
                messages[idx] = OpenAPIMessage(
                    role: .system,
                    content: .text(newContent),
                    name: messages[idx].name,
                    toolCalls: messages[idx].toolCalls,
                    toolCallId: messages[idx].toolCallId
                )
            } 
            else {
                messages.insert(OpenAPIMessage(
                    role: .system,
                    content: .text(toolPrompt),
                    name: nil,
                    toolCalls: nil,
                    toolCallId: nil
                ), at: 0)
            }
        }
        
        let lastMessage = messages.removeLast()
        resetChatSession(history: messages)

        return await streamResponse(to: lastMessage.content?.text ?? "", history: messages, inputRole: lastMessage.role)
    }

    private func generateToolPrompt(_ tools: [OpenAPITool]) -> String {
        guard let data = try? JSONEncoder().encode(tools), let json = String(data: data, encoding: .utf8) else { return "" }
        return "You have access to the following tools:\n\(json)\nIf you use a tool, output the function call in JSON format."
    }

    /// stream chat response
    /// - Parameter input: user input
    /// - Returns: response stream
    func streamResponse(to input: String, history: [OpenAPIMessage]? = nil, inputRole: ChatMessage.Role = .user) async -> AsyncThrowingStream<String, any Error> {
        guard let chatSession else {
            return AsyncThrowingStream { $0.finish(throwing: ModelManagerError.notInitialized) }
        }

        if let history {
            await chatHistoryStore.replace(with: history)
        }
        await chatHistoryStore.append(role: inputRole, content: input)
        
        // Start generation on all peers in parallel
        let request = GenerationRequest(
            requestID: UUID().uuidString,
            input: input,
            history: history,
            timestamp: Date()
        )

        let peers = coordinator?.ringPeers ?? []
        Task {
            await withTaskGroup(of: GenerationResponse?.self) { group in
                for peer in peers {
                    group.addTask {
                        await peer.client.startGeneration(request: request)
                    }
                }
            }
        }

        let originalStream = chatSession.streamDetails(to: input, images: [], videos: [])

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let task = Task { [weak self] in
            var fullReply = ""
            do {
                for try await chunk in originalStream {
                    switch chunk {
                    case .chunk(let text):
                        fullReply += text
                        continuation.yield(text)
                    case .info(let info):
                        self?.promptTokensPerSecond = info.promptTokensPerSecond
                        self?.tokensPerSecond = info.tokensPerSecond
                    case .toolCall(let tool):
                        // TODO: tool call
                        dprint("tool call \(tool)")
                        break
                    }
                }
                await self?.chatHistoryStore.append(role: .assistant, content: fullReply)
                continuation.finish()
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
        if let history = request.history {
            resetChatSession(history: history)
        }

        guard let chatSession else {
            return GenerationResponse(
                requestID: request.requestID,
                success: false,
                errorMessage: "ChatSession not initialized",
                timestamp: Date()
            )
        }

        do {
            await chatHistoryStore.append(role: .user, content: request.input)
            let response = try await chatSession.respond(to: request.input)
            await chatHistoryStore.append(role: .assistant, content: response)
            dprint(response)
            
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

    /// Reset chat session on all peers and local node
    func resetChatSessionAcrossPeers() async throws {
        resetChatSession()
        await chatHistoryStore.reset()

        let peers = coordinator?.ringPeers ?? []
        guard !peers.isEmpty else { return }

        let request = ChatResetRequest(
            requestID: UUID().uuidString,
            timestamp: Date()
        )
        var failures: [String] = []

        await withTaskGroup(of: (Int, ChatResetResponse?).self) { group in
            for peer in peers {
                group.addTask {
                    (peer.rank, await peer.client.resetChat(request: request))
                }
            }

            for await (rank, response) in group {
                guard let response else {
                    failures.append("peer \(rank): no response")
                    continue
                }
                if !response.success {
                    failures.append("peer \(rank): \(response.errorMessage ?? "unknown error")")
                }
            }
        }

        if !failures.isEmpty {
            throw ModelManagerError.peerResetFailed(failures.joined(separator: ", "))
        }
    }

    /// Handle chat reset request from peer
    func handleChatResetRequest(_ request: ChatResetRequest) async -> ChatResetResponse {
        resetChatSession()
        await chatHistoryStore.reset()
        return ChatResetResponse(
            requestID: request.requestID,
            success: true,
            errorMessage: nil,
            timestamp: Date()
        )
    }

    /// starts a new chat session
    /// - Parameter history: previous history, if nil starts with default system message
    private func resetChatSession(history: [OpenAPIMessage]? = nil) {
        guard let currentModel else {
            chatSession = nil
            Task { [chatHistoryStore] in
                await chatHistoryStore.reset()
            }
            return
        }
        let resolvedHistory = history?.map(\.resolvedChatMessage) ?? []

        if resolvedHistory.isEmpty {
            chatSession = ChatSession(
                currentModel,
                instructions: ChatMessage.systemMessage.content
            )
        }
        else {
            chatSession = ChatSession(currentModel, history: resolvedHistory.map {
                Chat.Message(role: $0.role.toRole, content: $0.content)
            })
        }
        Task { [chatHistoryStore, resolvedHistory] in
            await chatHistoryStore.replace(with: resolvedHistory)
        }
        Memory.clearCache()
    }

    /// Handle model load request from coordinator
    func handleModelLoadRequest(_ request: ModelLoadRequest, remoteHost: String?) async -> ModelLoadResponse {
        do {
            // Download cached files from peer if available
            if !request.availableFiles.isEmpty,
               let remoteHost,
               let peer = coordinator?.ringPeers.first(where: { $0.device.host == remoteHost }) {

#if os(iOS)
                Task { @MainActor in
                    UIApplication.shared.isIdleTimerDisabled = true
                }
#endif
                let cacheDir = request.modelCard.cacheDirectory

                dprint("Downloading \(request.availableFiles.count) cached files from peer \(remoteHost)")
                
                for fileName in request.availableFiles {
                    let destinationURL = cacheDir.appendingPathComponent(fileName)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        dprint("File already exists, skipping: \(fileName)")
                        continue
                    }
                    
                    do {
                        dprint("Downloading \(fileName) from peer...")
                        try await peer.client.download(
                            modelId: request.modelCard.shortId,
                            fileName: fileName,
                            destinationURL: destinationURL
                        )
                        dprint("Successfully downloaded: \(fileName)")
                    }
                    catch {
                        dprint("Failed to download \(fileName): \(error.localizedDescription)")
                        // Continue with other files
                    }
                }
            }
            
            ParallelModeSettings.useTensorParallel = request.shardMeta.useTensorParallel
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

    // MARK: - Private Methods

    /// Load model locally using MLXManager
    private func loadModelLocally(
        _ modelCard: ModelCard,
        shardMeta: ShardMetadata,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelLoadResponse? {
        guard let mlxManager else {
            throw ModelManagerError.notInitialized
        }
        // assume user is actively using the app after this point
#if os(iOS)
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = true
        }
#endif

        currentModel = try await mlxManager.loadModel(modelCard, shardMeta: shardMeta, progressHandler: progressHandler)
        return nil
    }
    
    /// assigns shards for ring devices per their memory % of total
    /// - Returns: shard metadatas, sorted by rank
    private func assignShardMetadata(modelCard: ModelCard) throws -> [ShardMetadata] {
        guard let coordinator else {
            throw ModelManagerError.notInitialized
        }
        let useTensorParallel = ParallelModeSettings.useTensorParallel
        let devices = coordinator.ringDevices.sorted { $0.rank < $1.rank }
        let totalMemory = coordinator.usableRAM
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
                useTensorParallel: useTensorParallel,
                startLayer: assignedLayers,
                endLayer: device.rank < size - 1 ? assignedLayers+shardLayers : nLayers,
                nLayers: nLayers
            ))
            assignedLayers += shardLayers
        }
        return metas
    }
}

private actor ChatHistoryStore {
    private var messages: [ChatMessage] = [.systemMessage]

    func snapshot() -> [ChatMessage] {
        messages
    }

    func reset() {
        messages = [.systemMessage]
    }

    func replace(with history: [OpenAPIMessage]) {
        replace(with: history.map(\.resolvedChatMessage))
    }

    func replace(with messages: [ChatMessage]) {
        self.messages = messages.isEmpty ? [.systemMessage] : messages
    }

    func append(role: ChatMessage.Role, content: String) {
        messages.append(ChatMessage(role: role, content: content))
    }
}

private extension OpenAPIMessage {
    var resolvedChatMessage: ChatMessage {
        var resolvedContent = content?.text ?? ""
        if resolvedContent.isEmpty,
           let toolCalls,
           !toolCalls.isEmpty,
           let data = try? JSONEncoder().encode(toolCalls),
           let json = String(data: data, encoding: .utf8) {
            resolvedContent = json
        }
        return ChatMessage(role: role, content: resolvedContent)
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case notInitialized
    case alreadyLoading
    case peerLoadingFailed(String)
    case peerResetFailed(String)
    case insufficientResources(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Dependencies not initialized"
        case .alreadyLoading:
            return "Model loading is already in progress"
        case .peerLoadingFailed(let message):
            return "Failed to load model on some peers: \(message)"
        case .peerResetFailed(let message):
            return "Failed to reset chat on some peers: \(message)"
        case .insufficientResources(let message):
            return "Insufficient system resources: \(message)"
        }
    }
}
