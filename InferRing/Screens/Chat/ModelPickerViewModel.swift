import Foundation
import SwiftUI
import Ring
import Observation

@Observable
@MainActor
class ModelPickerViewModel {
    var searchText: String = ""
    var displayDownloadedOnly = false
    var modelToDelete: ModelCard?
    var showDeleteConfirmation = false
    var showHelp = false
    var error: String?
    var lastUpdate = Date()

    var allCards: [ModelCard] {
        ModelCards.allModels.values
            .sorted { $0.metadata.prettyName.localizedCaseInsensitiveCompare($1.metadata.prettyName) == .orderedAscending }
    }

    var filteredCards: [ModelCard] {
        let _ = lastUpdate
        let cards = displayDownloadedOnly ? allCards.filter { $0.isLoaded } : allCards
        guard !searchText.trimmed.isEmpty else {
            return cards
        }
        let term = searchText.lowercased()
        return cards.filter { card in
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

    func refresh() {
        lastUpdate = Date()
    }

    func deleteModel() {
        guard let card = modelToDelete else { return }
        Task {
            try? await ModelCards.deleteModel(card)
            modelToDelete = nil
        }
    }
    
    func checkLoadedModels() {
        Task.detached {
            await ModelCards.checkLoadedModels()
            await MainActor.run {
                self.refresh()
            }
        }
    }
    
    func requestDelete(card: ModelCard, selectedModel: ModelCard?) {
        if selectedModel == card {
            error = "Cannot delete - model is currently used."
        }
        else {
            modelToDelete = card
            showDeleteConfirmation = true
        }
    }
}
