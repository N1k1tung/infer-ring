//

import SwiftUI

struct ContentView: View {
    @Environment(RingCoordinator.self) var coordinator
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showHelp = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            listContent
        } detail: {
            EmptyView()
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            NavigationLink("Browse Devices") {
                ServiceBrowserView()
            }
            NavigationLink("Ring Management") {
                RingManagementView()
            }
            NavigationLink("Chat") {
                ChatView()
            }
            NavigationLink("OpenAPI Server") {
                ServerView()
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
                    showHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $showHelp) {
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
}

#Preview {
    ContentView()
        .environment(RingCoordinator())
}
