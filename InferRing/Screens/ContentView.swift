//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Browse Devices") {
                    ServiceBrowserView()
                }
                
                NavigationLink("Ring Management") {
                    RingManagementView()
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
