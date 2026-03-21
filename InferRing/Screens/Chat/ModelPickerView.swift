import SwiftUI
import Ring

struct ModelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: ModelCard?
    @State private var viewModel = ModelPickerViewModel()

    init(selectedModel: Binding<ModelCard?>) {
        self._selectedModel = selectedModel
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredCards, id: \.shortId) { card in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.metadata.prettyName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(card.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)

                            HStack(spacing: 8) {
                                tagView(readableSize(card.metadata.storageSize))
                                ForEach(card.tags, id: \.self) {
                                    tagView($0)
                                }
                                if card.metadata.supportsTensor {
                                    tagView("Tensor parallel")
                                }
                                if card.isLoaded {
                                    tagView("Downloaded")
                                }
                                else if card.isPartiallyLoaded {
                                    tagView("Partially loaded")
                                }
                            }
                        }
                        Spacer()
                        if selectedModel?.shortId == card.shortId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModel = card
                        dismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if card.isLoaded || card.isPartiallyLoaded {
                            Button(role: .destructive) {
                                viewModel.requestDelete(card: card, selectedModel: selectedModel)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
#else
            .searchable(text: $viewModel.searchText)
#endif
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem {
                    Button {
                        viewModel.showHelp.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.glass)
                    .popover(isPresented: $viewModel.showHelp) {
                        Text("""
                            Models are downloaded from [Huggingface](https://huggingface.co/), or from the ring coordinator (if fully downloaded). 
                            Thus for optimizing network usage you can download on one device first, then form a ring, and open the same model triggering sharing across other peers.
                            
                            Models license information is available [here](https://n1k1tung.github.io/InferRingPrivacyPolicy/MODELS.html).
                            
                            You can swipe left to delete a downloaded model.
                            """)
                        .frame(minWidth: 280)
                        .padding()
                    }
                }
                ToolbarItem {
                    Toggle("Show downloaded only", isOn: $viewModel.displayDownloadedOnly)
#if os(iOS)
                        .toggleStyle(DefaultToggleStyle())
#else
                        .toggleStyle(CheckboxToggleStyle())
#endif
                }
            }
            .confirmationDialog("Delete Model?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete \(viewModel.modelToDelete?.metadata.prettyName ?? "")", role: .destructive) {
                    viewModel.deleteModel()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.modelToDelete = nil
                }
            } message: {
                Text("This will remove the model files from your device.")
            }
            .errorAlert($viewModel.error)
            .onAppear {
                viewModel.checkLoadedModels()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tagView(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func readableSize(_ memory: MemorySize) -> String {
        byteCountFormatter.string(fromByteCount: Int64(memory.inBytes))
    }

    private var byteCountFormatter = ByteCountFormatter() ~!~ {
        $0.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        $0.countStyle = .file
    }
}

#Preview {
    ModelPickerView(selectedModel: .constant(nil))
}
