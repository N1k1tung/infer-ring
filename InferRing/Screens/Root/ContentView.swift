//

import SwiftUI

struct ContentView: View {
    @Environment(RingCoordinator.self) var coordinator
    @State private var columnVisibility = NavigationSplitViewVisibility.all

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
        .navigationTitle("Infer Ring")
        .toolbar {
            ToolbarItem {
                StatusBadge()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(RingCoordinator())
}
