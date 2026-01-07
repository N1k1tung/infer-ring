//

import Foundation
import Ring
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
    
    /// Load a model across all peers in the ring (only callable by leader)
    func loadModelAcrossPeers(_ modelCard: ModelCard, progressHandler: @Sendable @escaping (_ progress: Double) -> Void = { _ in }) async throws {
        guard let coordinator else {
            throw ModelManagerError.notInitialized
        }
        
        guard !isLoading else {
            throw ModelManagerError.alreadyLoading
        }
        
        isLoading = true
        var loadingProgress = 0.0
        
        defer {
            isLoading = false
        }
        
        let request = ModelLoadRequest(
            modelCard: modelCard,
            requestID: UUID().uuidString,
            timestamp: Date()
        )
        
        let peers = coordinator.peers
        var responses: [ModelLoadResponse] = []
        
        await withTaskGroup(of: ModelLoadResponse?.self) { group in
            group.addTask { [weak self] in
                try? await self?.loadModelLocally(modelCard) { progress in
                    loadingProgress = progress.fractionCompleted * 0.5 // Local loading is 50% of total
                    progressHandler(loadingProgress)
                }
            }
            
            for peer in peers {
                group.addTask {
                    let client = DataClient.client(for: peer)
                    return await client.loadModel(request: request)
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
        loadingProgress = 1.0
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
        
        if let peers = coordinator?.peers {
            Task {
                await withTaskGroup(of: GenerationResponse?.self) { group in
                    for peer in peers {
                        group.addTask {
                            let client = DataClient.client(for: peer)
                            return await client.startGeneration(request: request)
                        }
                    }
                }
            }
        }
        
        return chatSession.streamResponse(to: input)
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

            return GenerationResponse(
                requestID: request.requestID,
                success: true,
                errorMessage: nil,
                timestamp: Date()
            )
        } catch {
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
    }

    /// Handle model load request from coordinator
    func handleModelLoadRequest(_ request: ModelLoadRequest) async -> ModelLoadResponse {
        do {
            _ = try await loadModelLocally(request.modelCard) { _ in }
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

    // MARK: - Internal Methods
    
    /// Load model locally using MLXManager
    private func loadModelLocally(
        _ modelCard: ModelCard,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelLoadResponse? {
        guard let mlxManager = mlxManager else {
            throw ModelManagerError.notInitialized
        }
        
        currentModel = try await mlxManager.loadModel(modelCard, progressHandler: progressHandler)
        return nil
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case notInitialized
    case alreadyLoading
    case peerLoadingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Dependencies not initialized"
        case .alreadyLoading:
            return "Model loading is already in progress"
        case .peerLoadingFailed(let message):
            return "Failed to load model on some peers: \(message)"
        }
    }
}


