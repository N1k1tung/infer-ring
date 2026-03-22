//

import Foundation
import Ring
import MLX
import MLXLMCommon
import MLXLLM
import Tokenizers
internal import ConcurrencyExtras
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
    private var currentToolSignature: Data?
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
    func streamResponse(
        to messages: [OpenAPIMessage],
        tools: [OpenAPITool]? = nil
    ) async -> AsyncThrowingStream<ModelResponseChunk, any Error> {
        var messages = messages
        guard let lastMessage = messages.popLast() else {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: ModelManagerError.invalidRequest("Chat request must include at least one message")
                )
            }
        }
        return await streamResponseChunks(
            to: lastMessage.content?.text ?? "",
            images: (lastMessage.content?.imageURLs ?? []).map { ChatImageAttachment(url: $0) },
            history: messages,
            inputRole: lastMessage.role,
            tools: tools
        )
    }

    /// stream chat response (text only)
    /// - Parameter input: user input
    /// - Returns: response stream
    func streamResponse(
        to input: String,
        images: [ChatImageAttachment] = [],
        history: [OpenAPIMessage]? = nil,
        inputRole: ChatMessage.Role = .user,
        tools: [OpenAPITool]? = nil
    ) async -> AsyncThrowingStream<String, any Error> {
        await streamResponseChunks(
            to: input,
            images: images,
            history: history,
            inputRole: inputRole,
            tools: tools
        )
        .compactMap { chunk -> String? in
            guard case .text(let text) = chunk else { return nil }
            return text
        }
        .eraseToThrowingStream()
    }


    /// chunks stream (all types)
    private func streamResponseChunks(
        to input: String,
        images: [ChatImageAttachment] = [],
        history: [OpenAPIMessage]? = nil,
        inputRole: ChatMessage.Role = .user,
        tools: [OpenAPITool]? = nil,
        distributeToPeers: Bool = true
    ) async -> AsyncThrowingStream<ModelResponseChunk, any Error> {
        if await shouldResetChatSession(history: history, tools: tools) {
            resetChatSession(history: history, tools: tools?.toolSpecs)
            currentToolSignature = toolSignature(for: tools)
        }

        guard let chatSession else {
            return AsyncThrowingStream { $0.finish(throwing: ModelManagerError.notInitialized) }
        }

        if let history {
            await chatHistoryStore.replace(with: history)
        }
        await chatHistoryStore.append(role: inputRole, content: input, images: images)
        
        if distributeToPeers {
            let request = GenerationRequest(
                requestID: UUID().uuidString,
                input: input,
                inputRole: inputRole,
                history: history,
                tools: tools,
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
        }

        let originalStream = chatSession.streamDetails(
            to: input,
            role: inputRole.toRole,
            images: images.map(\.userInputImage),
            videos: []
        )

        let (stream, continuation) = AsyncThrowingStream<ModelResponseChunk, Error>.makeStream()
        let task = Task { [weak self] in
            var fullReply = ""
            var toolCalls: [ModelResponseToolCall] = []
            do {
                for try await chunk in originalStream {
                    switch chunk {
                    case .chunk(let text):
                        fullReply += text
                        continuation.yield(.text(text))
                    case .info(let info):
                        self?.promptTokensPerSecond = info.promptTokensPerSecond
                        self?.tokensPerSecond = info.tokensPerSecond
                    case .toolCall(let tool):
                        let toolCall = tool.modelResponseToolCall
                        toolCalls.append(toolCall)
                        continuation.yield(.toolCall(toolCall))
                    }
                }
                await self?.chatHistoryStore.append(
                    role: .assistant,
                    content: Self.assistantHistoryContent(text: fullReply, toolCalls: toolCalls)
                )
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
        do {
            let stream = await streamResponseChunks(
                to: request.input,
                history: request.history,
                inputRole: request.inputRole,
                tools: request.tools,
                distributeToPeers: false
            )
            for try await _ in stream {}
            
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
    private func resetChatSession(history: [OpenAPIMessage]? = nil, tools: [ToolSpec]? = nil) {
        guard let currentModel else {
            chatSession = nil
            currentToolSignature = nil
            if history == nil {
                ChatImageAttachmentStore.removeAll()
            }
            Task { [chatHistoryStore] in
                await chatHistoryStore.reset()
            }
            return
        }
        let resolvedHistory = history?.map(\.resolvedChatMessage) ?? []

        if history == nil {
            ChatImageAttachmentStore.removeAll()
        }

        if resolvedHistory.isEmpty {
            chatSession = ChatSession(
                currentModel,
                instructions: ChatMessage.systemMessage.content,
                tools: tools
            )
        }
        else {
            chatSession = ChatSession(
                currentModel,
                history: resolvedHistory.map {
                    Chat.Message(
                        role: $0.role.toRole,
                        content: $0.content,
                        images: $0.images.map(\.userInputImage)
                    )
                },
                tools: tools
            )
        }
        Task { [chatHistoryStore, resolvedHistory] in
            await chatHistoryStore.replace(with: resolvedHistory)
        }
        if tools == nil {
            currentToolSignature = nil
        }
        Memory.clearCache()
    }

    private func shouldResetChatSession(
        history: [OpenAPIMessage]? = nil,
        tools: [OpenAPITool]? = nil
    ) async -> Bool {
        guard currentModel != nil else { return false }
        guard chatSession != nil else { return true }
        guard toolSignature(for: tools) == currentToolSignature else { return true }
        guard let history else { return false }

        let requestedHistory = history.map(\.resolvedChatMessage)
        let requestedConversation = (
            requestedHistory.isEmpty ? [.systemMessage] : requestedHistory
        ).conversationSignature
        let currentConversation = (await chatHistoryStore.snapshot()).conversationSignature
        return requestedConversation != currentConversation
    }

    private func toolSignature(for tools: [OpenAPITool]?) -> Data? {
        guard let tools else { return nil }
        return try? JSONEncoder.default.encode(tools)
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

    func append(role: ChatMessage.Role, content: String, images: [ChatImageAttachment] = []) {
        messages.append(ChatMessage(role: role, content: content, images: images))
    }
}

private extension OpenAPIMessage {
    var resolvedChatMessage: ChatMessage {
        var parts: [String] = []
        let text = content?.text ?? ""
        let images = (content?.imageURLs ?? []).map { ChatImageAttachment(url: $0) }
        if !text.isEmpty {
            parts.append(text)
        }
        if let toolCalls,
           let normalizedToolCalls = normalizedToolCallContent(toolCalls),
           !normalizedToolCalls.isEmpty {
            parts.append(normalizedToolCalls)
        }
        return ChatMessage(
            role: role,
            content: parts.joined(separator: "\n\n"),
            images: images
        )
    }
}

private extension Array where Element == ChatMessage {
    var conversationSignature: [ConversationMessageSignature] {
        map {
            ConversationMessageSignature(
                role: $0.role,
                content: $0.content,
                images: $0.images.map { $0.url.absoluteString }
            )
        }
    }
}

private struct ConversationMessageSignature: Equatable {
    let role: ChatMessage.Role
    let content: String
    let images: [String]
}

private struct NormalizedToolCall: Codable {
    let name: String
    let arguments: String

    init(_ toolCall: OpenAPIToolCall) {
        self.name = toolCall.function.name
        self.arguments = toolCall.function.arguments
    }

    init(_ toolCall: ModelResponseToolCall) {
        self.name = toolCall.name
        self.arguments = toolCall.arguments
    }
}

private func normalizedToolCallContent(_ toolCalls: [OpenAPIToolCall]) -> String? {
    guard !toolCalls.isEmpty,
          let data = try? JSONEncoder().encode(toolCalls.map(NormalizedToolCall.init)),
          let json = String(data: data, encoding: .utf8) else {
        return nil
    }
    return json
}

private func normalizedToolCallContent(_ toolCalls: [ModelResponseToolCall]) -> String? {
    guard !toolCalls.isEmpty,
          let data = try? JSONEncoder().encode(toolCalls.map(NormalizedToolCall.init)),
          let json = String(data: data, encoding: .utf8) else {
        return nil
    }
    return json
}

private extension ModelManager {
    static func assistantHistoryContent(text: String, toolCalls: [ModelResponseToolCall]) -> String {
        var parts: [String] = []
        if !text.isEmpty {
            parts.append(text)
        }
        if let normalizedToolCalls = normalizedToolCallContent(toolCalls),
           !normalizedToolCalls.isEmpty {
            parts.append(normalizedToolCalls)
        }
        return parts.joined(separator: "\n\n")
    }
}

private extension Collection where Element == OpenAPITool {
    var toolSpecs: [ToolSpec] {
        compactMap(\.toolSpec)
    }
}

private extension OpenAPITool {
    var toolSpec: ToolSpec? {
        var functionSpec: [String: any Sendable] = [
            "name": function.name
        ]
        if let description = function.description {
            functionSpec["description"] = description
        }
        if let parameters = function.parameters?.sendableDictionary {
            functionSpec["parameters"] = parameters
        }
        return [
            "type": type,
            "function": functionSpec,
        ]
    }
}

private extension Dictionary where Key == String, Value == AnyCodable {
    var sendableDictionary: [String: any Sendable]? {
        var converted: [String: any Sendable] = [:]
        converted.reserveCapacity(count)
        for (key, value) in self {
            guard let sendableValue = value.sendableValue else {
                return nil
            }
            converted[key] = sendableValue
        }
        return converted
    }
}

private extension AnyCodable {
    var sendableValue: (any Sendable)? {
        switch value {
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let string as String:
            return string
        case let array as [Any]:
            var converted: [any Sendable] = []
            converted.reserveCapacity(array.count)
            for element in array {
                guard let sendableValue = AnyCodable(element).sendableValue else {
                    return nil
                }
                converted.append(sendableValue)
            }
            return converted
        case let array as [AnyCodable]:
            var converted: [any Sendable] = []
            converted.reserveCapacity(array.count)
            for element in array {
                guard let sendableValue = element.sendableValue else {
                    return nil
                }
                converted.append(sendableValue)
            }
            return converted
        case let dictionary as [String: Any]:
            var converted: [String: any Sendable] = [:]
            converted.reserveCapacity(dictionary.count)
            for (key, value) in dictionary {
                guard let sendableValue = AnyCodable(value).sendableValue else {
                    return nil
                }
                converted[key] = sendableValue
            }
            return converted
        case let dictionary as [String: AnyCodable]:
            return dictionary.sendableDictionary
        default:
            return nil
        }
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case notInitialized
    case alreadyLoading
    case peerLoadingFailed(String)
    case peerResetFailed(String)
    case insufficientResources(String)
    case distributedVisionNotSupported
    case invalidRequest(String)
    
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
        case .distributedVisionNotSupported:
            return "Vision inputs are currently only supported for local inference."
        case .invalidRequest(let message):
            return message
        }
    }
}
