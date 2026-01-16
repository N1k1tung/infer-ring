//
import Foundation
import Observation
import Ring

@Observable
@MainActor
final class ServerViewModel {

    var isShowingModelPicker: Bool = false
    var errorMessage: String? = nil
    var loadingPercent: Double? = nil

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

    @ObservationIgnored
    @Inject
    private var modelManager: ModelManager?

    init() {
        selectedModel = modelManager?.currentModelCard

        Task { @MainActor in
            for await loadedModel in Observations({ [weak self] in
                self?.modelManager?.currentModelCard
            }) {
                selectedModel = loadedModel
            }
        }
    }

}
