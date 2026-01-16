//

import SwiftUI

struct ServerView: View {
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    Text("Running at:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("http://localhost:12345")
                        .font(.title)
                        .bold()
                }
            }
        }
        .navigationTitle("OpenAPI Server")
    }
}

#Preview {
    ServerView()
}
