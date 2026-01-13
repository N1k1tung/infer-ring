import SwiftUI

struct ServiceBrowserView: View {
    @Environment(BonjourClient.self) var bonjourClient

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(bonjourClient.nodes, id: \.self) { service in
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .font(.headline)
                            Text(service.host)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if bonjourClient.isSearching {
                    ProgressView()
                }
            }
            .navigationTitle("Services")
            .onAppear {
                Task {
                    bonjourClient.startSearching()
                }
            }
            .onDisappear {
                Task {
                    bonjourClient.stopSearching()
                }
            }
            .toolbar {
                ToolbarItem() {
                    Button("Refresh") {
                        Task {
                            bonjourClient.startSearching()
                        }
                    }
                }
            }
        }
    }
}
