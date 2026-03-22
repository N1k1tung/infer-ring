import Foundation
import Observation
import Ring

#if os(iOS)
import UIKit
#else
import AppKit
#endif

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = [.systemMessage]
    var input: String = ""
    var pendingImages: [ChatImageAttachment] = []
    private(set) var isSending: Bool = false
    var selectedModel: ModelCard? {
        didSet {
            if isVisionModelSelected {
                pendingImages = []
            }
            guard let selectedModel,
                  selectedModel != oldValue,
                  selectedModel != modelManager?.currentModelCard
            else { return }

            Task {
                do {
                    try await modelManager?.loadModelAcrossPeers(selectedModel) { [weak self] progress in
                        Task { @MainActor in
                            self?.loadingPercent = progress
                        }
                    }
                    loadingPercent = nil
                }
                catch {
                    dprint(error)
                    errorMessage = "Failed to load model: \(error.localizedDescription)"
                    loadingPercent = nil
                    self.selectedModel = oldValue
                }
            }
        }
    }
    var canSend: Bool {
        guard selectedModel != nil, !isSending else { return false }
        return !input.trimmed.isEmpty || !pendingImages.isEmpty
    }
    var isVisionModelSelected: Bool {
        selectedModel?.isVisionModel == true
    }
    var canAttachImages: Bool {
        isVisionModelSelected && !isSending
    }
    var isShowingModelPicker: Bool = false
    var isShowingImageImporter: Bool = false
    var isShowingToast: Bool = false

    var errorMessage: String? = nil
    private(set) var loadingPercent: Double? = nil
    private(set) var tokensPerSecond: Double? = nil
    private(set) var promptTokensPerSecond: Double? = nil

    private var displayLink: CADisplayLink?
    private var displayedContent: String = ""
    private var streamedMessageIndex: Int?

    @ObservationIgnored
    @Inject
    private var modelManager: ModelManager?
    
    init() {
        selectedModel = modelManager?.currentModelCard
        refreshMessages()

        Task { @MainActor in
            for await loadedModel in Observations({ [weak self] in
                self?.modelManager?.currentModelCard
            }) {
                selectedModel = loadedModel
                resetChatUI()
            }
        }
    }

    func send() async throws {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingImages = self.pendingImages
        guard (!trimmedInput.isEmpty || !pendingImages.isEmpty),
              !isSending,
              let modelManager
            else { return }
        isSending = true
        defer { isSending = false }
        tokensPerSecond = nil
        promptTokensPerSecond = nil

        let userMessage = ChatMessage(role: .user, content: trimmedInput, images: pendingImages)
        messages.append(userMessage)
        input = ""
        self.pendingImages = []

        let assistantMessage = ChatMessage(role: .assistant, content: "...")
        messages.append(assistantMessage)
        let index = messages.count - 1

        streamedMessageIndex = index
        displayedContent = "..."
        startDisplayLinkIfNeeded()

        var fullReply = ""
        let stream = await modelManager.streamResponse(to: trimmedInput, images: pendingImages)
        for try await replyStream in stream {
            fullReply += replyStream
            displayedContent = fullReply
        }
        messages[index].content = fullReply
        tokensPerSecond = modelManager.tokensPerSecond
        promptTokensPerSecond = modelManager.promptTokensPerSecond

        stopDisplayLink()
    }

    func reset() {
        guard !isSending else { return }
        isSending = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isSending = false }

            do {
                if let modelManager = self.modelManager {
                    try await modelManager.resetChatSessionAcrossPeers()
                }
                self.resetChatUI()
            }
            catch {
                self.errorMessage = "Failed to reset chat on all peers: \(error.localizedDescription)"
                self.messages = await self.modelManager?.messageHistory() ?? [.systemMessage]
            }
        }
    }

    private func resetChatUI() {
        input = ""
        pendingImages = []
        isShowingImageImporter = false
        isSending = false
        stopDisplayLink()
        refreshMessages()
    }

    func refreshMessages() {
        guard !isSending else { return }
        Task { [weak self] in
            guard let self else { return }
            messages = await modelManager?.messageHistory() ?? [.systemMessage]
        }
    }

    func importImages(from urls: [URL]) {
        guard !urls.isEmpty else { return }

        var importedImages: [ChatImageAttachment] = []
        var failures: [String] = []

        for url in urls {
            do {
                importedImages.append(try ChatImageAttachmentStore.importImage(from: url))
            }
            catch {
                failures.append(url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)
            }
        }

        pendingImages.append(contentsOf: importedImages)

        if !failures.isEmpty {
            errorMessage = "Failed to import: \(failures.joined(separator: ", "))"
        }
    }

    func removePendingImage(_ image: ChatImageAttachment) {
        pendingImages.removeAll { $0.id == image.id }
    }

    // MARK: display optimizations
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
#if os(iOS)
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
#else
        let link = NSApplication.shared.keyWindow?.displayLink(target: self, selector: #selector(handleDisplayLinkTick)) ?? CADisplayLink()
#endif
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayedContent = ""
        streamedMessageIndex = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLinkTick() {
        guard let index = streamedMessageIndex, !displayedContent.isEmpty else { return }
        messages[index].content = displayedContent
    }
}
