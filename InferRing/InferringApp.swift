//

import SwiftUI

@main
struct InferringApp: App {
    @State private var bonjourClient = BonjourClient()
    @State private var bonjourServer = BonjourServer()
    @State private var ringCoordinator = RingCoordinator()
    private let dataServer = DataServer()
    init() {
        DI.register(ringCoordinator)
        dataServer.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(bonjourClient)
        .environment(bonjourServer)
        .environment(ringCoordinator)
    }
}
