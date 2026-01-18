import SwiftUI

struct ServiceBrowserView: View {
    @Environment(BonjourClient.self) var bonjourClient

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if bonjourClient.permissionDenied {
                    PermissionErrorBanner()
                        .padding()
                }
                
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
                if bonjourClient.isSearching {
                    Button("Stop") {
                        Task {
                            bonjourClient.stopSearching()
                        }
                    }
                }
                else {
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
