//

import SwiftUI
import Ring
import Textual

struct ContentView: View {
    @Environment(RingCoordinator.self) var coordinator
    @Environment(ModelManager.self) var modelManager
    @AppStorage(ParallelModeSettings.useTensorParallelKey) private var useTensorParallel = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showGeneralHelp = false
    @State private var showTensorParallelHelp = false
    @State private var showReloadPrompt = false
    @State private var reloadCandidate: ModelCard?
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            listContent
        } detail: {
            EmptyView()
        }
        .onChange(of: useTensorParallel) { _, _ in
            guard let loadedModel = modelManager.currentModelCard, loadedModel.metadata.supportsTensor else { return }
            reloadCandidate = loadedModel
            showReloadPrompt = true
        }
        .alert("Reload Model?", isPresented: $showReloadPrompt, presenting: reloadCandidate) { model in
            Button("Reload") {
                reloadModel(model)
            }
            Button("Later", role: .cancel) {
                reloadCandidate = nil
            }
        } message: { model in
            Text("\(model.metadata.prettyName) is loaded. Reload now to apply \(useTensorParallel ? "tensor parallel" : "pipeline parallel")?")
        }
        .errorAlert($errorMessage)
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section("Manage") {
                NavigationLink("Ring Management") {
                    RingManagementView()
                }
                NavigationLink("Browse Devices") {
                    ServiceBrowserView()
                }
                if coordinator.currentRing != nil {
                    HStack {
                        Toggle("Tensor Parallelism", isOn: $useTensorParallel)
                            .disabled(modelManager.isLoading)
                        Button {
                            showTensorParallelHelp.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.glass)
                        .popover(isPresented: $showTensorParallelHelp) {
                            StructuredText(markdown: """
                            Tensor parallelism splits each layer computation across devices, so multiple devices process different tensor shards of the same layer at the same time.

                            Pipeline parallelism splits by layers, where each device owns different layer ranges and passes activations between stages. Tensor parallelism instead keeps devices synchronized within the same layers.

                            Tensor parallelism needs frequent low-latency all-reduce and all-gather traffic, so it benefits from RDMA over Thunderbolt 5. Without that bandwidth and latency, communication overhead is high and it is typically slower than pipeline parallelism.
                            """)
                            .frame(minWidth: 280, minHeight: 280)
                            .padding()
                        }
                    }
                }
            }
            Section("Use") {
                NavigationLink("Chat") {
                    ChatView()
                }
                NavigationLink("OpenAPI Server") {
                    ServerView()
                }
            }
        }
        .frame(minWidth: 300)
        .navigationTitle("Infer Ring")
        .toolbar {
            ToolbarItem {
                StatusBadge()
            }
            ToolbarItem {
                Button {
                    showGeneralHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $showGeneralHelp) {
                    Text("""
                            Infer Ring facitilates distributed inferrence across iOS and MacOS devices using [MLX Swift](https://github.com/ml-explore/mlx-swift) using ring topology.
                            
                            Application automatically detects devices running the same app in the local network or connected via USB cable.
                            Thus in order to form an inference ring with your device simply open the app on all of them and observe the status indicator.
                            For more information on ring formation and troubleshooting refer to 'Ring Management' section.
                            
                            You can view accessible devices running the app in the 'Browse Devices' section.
                            
                            In order to load a model on all connected devices simply select a model from picker inside 'Chat' or 'OpenAPI Server' sections.
                            Afterwards you can use model via provided Chat or connect external tools to it via provided OpenAPI-compatible server.
                            """)
                    .frame(minWidth: 280)
                    .padding()
                }
            }
        }
    }

    private func reloadModel(_ model: ModelCard) {
        Task {
            do {
                try await modelManager.loadModelAcrossPeers(model)
            }
            catch {
                errorMessage = "Failed to reload model: \(error.localizedDescription)"
            }
            reloadCandidate = nil
        }
    }
}

#Preview {
    ContentView()
        .environment(RingCoordinator())
        .environment(ModelManager())
}
