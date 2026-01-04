//

import SwiftUI

struct ContentView: View {
    @Environment(RingCoordinator.self) var coordinator
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        content
    }
    
    @ViewBuilder
    var content: some View {
        splitView
    }

    var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            listContent
        } detail: {
            Text("Select an item")
                .foregroundStyle(.secondary)
        }
    }

    var stackView: some View {
        NavigationStack {
            listContent
        }
    }

    @ViewBuilder
    var listContent: some View {
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
        }
        .navigationTitle("Home")
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
