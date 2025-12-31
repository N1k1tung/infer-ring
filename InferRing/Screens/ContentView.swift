//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Browse Devices") {
                    ServiceBrowserView()
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
