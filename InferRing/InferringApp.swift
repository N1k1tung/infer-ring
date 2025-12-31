//

import SwiftUI

@main
struct InferringApp: App {
    @State private var bonjourClient = BonjourClient()
    @State private var bonjourServer = BonjourServer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(bonjourClient)
        .environment(bonjourServer)
    }
}
