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
    var isSending: Bool = false
    var selectedModel: ModelCard? {
        didSet {
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
        selectedModel != nil && !isSending && !input.trimmed.isEmpty
    }
    var isShowingModelPicker: Bool = false
    var isShowingToast: Bool = false

    var errorMessage: String? = nil
    var loadingPercent: Double? = nil
    var tokensPerSecond: Double? = nil

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
        guard !trimmedInput.isEmpty,
              !isSending,
              let modelManager
            else { return }
        isSending = true
        defer { isSending = false }

        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        messages.append(userMessage)
        input = ""

        let assistantMessage = ChatMessage(role: .assistant, content: "...")
        messages.append(assistantMessage)
        let index = messages.count - 1

        streamedMessageIndex = index
        displayedContent = "..."
        startDisplayLinkIfNeeded()

        var fullReply = ""
        for try await replyStream in modelManager.streamResponse(to: trimmedInput) {
            fullReply += replyStream
            displayedContent = fullReply
        }
        messages[index].content = fullReply
        tokensPerSecond = modelManager.tokensPerSecond

        stopDisplayLink()
    }

    func reset() {
        modelManager?.resetChatSession()
        resetChatUI()
    }

    private func resetChatUI() {
        input = ""
        isSending = false
        stopDisplayLink()
        refreshMessages()
    }

    func refreshMessages() {
        guard !isSending else { return }
        messages = modelManager?.messages ?? [.systemMessage]
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
