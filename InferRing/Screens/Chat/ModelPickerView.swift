import SwiftUI
import Ring

struct ModelPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedModel: ModelCard?

    @State private var searchText: String = ""

    private var allCards: [ModelCard] {
        ModelCards.allModels.values
            .sorted { $0.metadata.prettyName.localizedCaseInsensitiveCompare($1.metadata.prettyName) == .orderedAscending }
    }

    private var filteredCards: [ModelCard] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allCards }
        let term = searchText.lowercased()
        return allCards.filter { card in
            let fields: [String] = [
                card.name,
                card.metadata.prettyName,
                card.modelId,
                card.shortId,
                card.description
            ] + card.tags
            return fields.joined(separator: " ").lowercased().contains(term)
        }
    }

    init(selectedModel: Binding<ModelCard?>) {
        self._selectedModel = selectedModel
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCards, id: \.shortId) { card in
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
                                Text(readableSize(card.metadata.storageSize))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                if card.metadata.supportsTensor {
                                    Text("Tensor")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
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
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            #else
            .searchable(text: $searchText)
            #endif
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func readableSize(_ memory: MemorySize) -> String {
        byteCountFormatter.string(fromByteCount: Int64(memory.inBytes))
    }

    private var byteCountFormatter = ByteCountFormatter() ~!~ {
        $0.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        $0.countStyle = .file
    }
}

#Preview("Model Picker") {
    // Provide a simple preview with a local state
    struct PreviewHost: View {
        @State private var selection: ModelCard? = nil
        var body: some View {
            ModelPickerView(selectedModel: $selection)
        }
    }
    return PreviewHost()
}
