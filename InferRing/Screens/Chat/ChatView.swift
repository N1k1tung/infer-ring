import SwiftUI
import Observation
import Ring
import Textual
import UniformTypeIdentifiers

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .onTapGesture {
                                    guard !message.content.isEmpty else { return }
                                    Pasteboard.setText(message.content)
                                    viewModel.isShowingToast = true
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation { viewModel.isShowingToast = false }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onChange(of: viewModel.messages) { _, _ in
                    if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            Divider()
            messageContainer
        }
        .overlay(alignment: .bottom) {
            if viewModel.isShowingToast {
                Toast(message: "Copied to Clipboard")
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem {
                Button("Reset") { viewModel.reset() }
                    .disabled(viewModel.isSending)
            }
        }
        .sheet(isPresented: $viewModel.isShowingModelPicker) {
            ModelPickerView(selectedModel: $viewModel.selectedModel)
                .frame(minHeight: 560)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImageImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.importImages(from: urls)
            case .failure(let error):
                viewModel.errorMessage = "Failed to import images: \(error.localizedDescription)"
            }
        }
        .errorAlert($viewModel.errorMessage)
        .onAppear {
            viewModel.refreshMessages()
        }
    }

    @ViewBuilder
    private var messageContainer: some View {
        ZStack {
            VStack(spacing: 4) {
                if !viewModel.pendingImages.isEmpty {
                    DraftImageStrip(
                        images: viewModel.pendingImages,
                        onRemove: viewModel.removePendingImage
                    )
                }
                if viewModel.isShowingGenerationOptions {
                    GenerationOptionsPanel(
                        options: Binding(
                            get: { viewModel.generationOptions },
                            set: { viewModel.generationOptions = $0 }
                        ),
                        isDisabled: viewModel.isSending,
                        onReset: viewModel.resetGenerationOptions
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                TextField("Message", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .disabled(viewModel.isSending)
                    .submitLabel(.send)
                    .onSubmit {
                        guard viewModel.canSend else { return }
                        Task { try? await viewModel.send() }
                    }
                HStack {
                    if let tps = viewModel.tokensPerSecond,
                       let pp = viewModel.promptTokensPerSecond {
                        Text("PP\t\(pp, specifier: "%.2f") tps\nTG\t\(tps, specifier: "%.2f") tps")
                    }
                    Spacer()
                    if let loadingPercent = viewModel.loadingPercent {
                        Text("\(loadingPercent * 100, specifier: "%.0f")%")
                        ProgressView(value: loadingPercent)
                            .progressViewStyle(.circular)
                    }
                    if viewModel.isVisionModelSelected {
                        Button {
                            viewModel.isShowingImageImporter = true
                        } label: {
                            Image(systemName: "photo.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canAttachImages)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isShowingGenerationOptions.toggle()
                        }
                    } label: {
                        Image(
                            systemName: viewModel.isShowingGenerationOptions
                                ? "slider.horizontal.3.circle.fill"
                                : "slider.horizontal.3"
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        viewModel.generationOptions == .defaults ? .secondary : Color.accentColor
                    )
                    .disabled(viewModel.isSending)
                    Button {
                        viewModel.isShowingModelPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedModel?.metadata.prettyName ?? "Select model")
                            Image(systemName: "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { try? await viewModel.send() }
                    } label: {
                        if viewModel.isSending {
                            ProgressView()
                        }
                        else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .frame(maxHeight: 30)
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSend)
                    #if os(macOS)
                    .keyboardShortcut(.return)
                    #endif
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
            )
        }
        .padding(8)
        .background(.bar)
    }

}

private struct GenerationOptionsPanel: View {
    @Binding var options: ChatGenerationOptions
    let isDisabled: Bool
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generation Options")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Defaults", action: onReset)
                    .font(.caption)
                    .buttonStyle(.plain)
            }

            HStack {
                Text("KV Cache")
                Spacer()
                Picker("KV Cache", selection: kvBitsBinding) {
                    ForEach(ChatGenerationOptions.KVBitsOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            SliderSettingRow(
                title: "Temperature",
                value: temperatureBinding,
                range: 0 ... 2,
                step: 0.05
            )

            StepperSettingRow(
                title: "Top-K",
                value: topKBinding,
                range: 0 ... 256,
                step: 1
            )

            SliderSettingRow(
                title: "Top-P",
                value: topPBinding,
                range: 0 ... 1,
                step: 0.01
            )

            SliderSettingRow(
                title: "Min-P",
                value: minPBinding,
                range: 0 ... 1,
                step: 0.01
            )

            Toggle("Repetition Penalty", isOn: repetitionPenaltyEnabled)

            if options.repetitionPenalty != nil {
                SliderSettingRow(
                    title: "Penalty",
                    value: repetitionPenaltyBinding,
                    range: 1.0 ... 2.0,
                    step: 0.05
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
        .disabled(isDisabled)
    }

    private var kvBitsBinding: Binding<ChatGenerationOptions.KVBitsOption> {
        Binding(
            get: { options.kvBits },
            set: { options.kvBits = $0 }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { options.temperature },
            set: { options.temperature = $0.clamped(to: 0 ... 2) }
        )
    }

    private var topKBinding: Binding<Int> {
        Binding(
            get: { options.topK },
            set: { options.topK = min(max($0, 0), 256) }
        )
    }

    private var topPBinding: Binding<Double> {
        Binding(
            get: { options.topP },
            set: { options.topP = $0.clamped(to: 0 ... 1) }
        )
    }

    private var minPBinding: Binding<Double> {
        Binding(
            get: { options.minP },
            set: { options.minP = $0.clamped(to: 0 ... 1) }
        )
    }

    private var repetitionPenaltyEnabled: Binding<Bool> {
        Binding(
            get: { options.repetitionPenalty != nil },
            set: { isEnabled in
                options.repetitionPenalty = isEnabled ? max(options.repetitionPenalty ?? 1.1, 1.0) : nil
            }
        )
    }

    private var repetitionPenaltyBinding: Binding<Double> {
        Binding(
            get: { options.repetitionPenalty ?? 1.1 },
            set: { options.repetitionPenalty = $0.clamped(to: 1.0 ... 2.0) }
        )
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .assistant || message.role == .system {
                bubble
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
                bubble
            }
        }
    }
    
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.role == .system || message.role == .tool {
                Text(message.role.rawValue.localizedCapitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !message.images.isEmpty {
                MessageImageStrip(images: message.images)
            }
            if !message.content.isEmpty {
                StructuredText(markdown: message.content)
                    .foregroundStyle(message.role == .system ? .secondary : .primary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.15)
        case .assistant:
            return Color.gray.opacity(0.15)
        case .system, .tool:
            return Color.secondary.opacity(0.1)
        }
    }
}

private struct SliderSettingRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

private struct StepperSettingRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $value, in: range, step: step) {
                Text("\(value)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    NavigationStack { ChatView() }
}
