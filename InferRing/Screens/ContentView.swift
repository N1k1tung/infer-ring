//

import SwiftUI

struct ContentView: View {
    @Environment(RingCoordinator.self) var coordinator

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Browse Devices") {
                    ServiceBrowserView()
                }
                
                NavigationLink("Ring Management") {
                    RingManagementView()
                }
                NavigationLink("Open chat") {
                    ChatView()
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem() {
                    StatusBadge()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
