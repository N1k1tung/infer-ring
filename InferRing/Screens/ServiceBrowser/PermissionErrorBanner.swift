import SwiftUI

struct PermissionErrorBanner: View {
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Local Network Permission Required")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(.white)
                
                Text("Please enable Local Network access to allow discovery of other devices.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 16)
            
            Button("Settings") {
                openSettings()
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
    }
    
    private func openSettings() {
        #if os(macOS)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
                NSWorkspace.shared.open(url)
            }
            else {
                 NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            }
        #elseif os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #endif
    }
}

#Preview {
    PermissionErrorBanner()
        .padding()
        .background(Color.black)
}
