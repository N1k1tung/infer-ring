//
import SwiftUI
import Ring

struct ServerView: View {
    @State private var viewModel = ServerViewModel()

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    if let loadingPercent = viewModel.loadingPercent {
                        Text("\(loadingPercent * 100, specifier: "%.0f")%")
                        ProgressView(value: loadingPercent)
                            .progressViewStyle(.circular)
                    }
                    Button {
                        viewModel.isShowingModelPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedModel?.metadata.prettyName ?? "Select model")
                            Image(systemName: "chevron.down")
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                    .frame(height: 20)
                if viewModel.selectedModel != nil {
                    Text("Running at:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("http://localhost:12345")
                        .font(.title)
                        .bold()
                }
                else {
                    Text("Server is automatically started after loading a model.")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("OpenAPI Server")
        .sheet(isPresented: $viewModel.isShowingModelPicker) {
            ModelPickerView(selectedModel: $viewModel.selectedModel)
                .frame(minHeight: 560)
        }
        .errorAlert($viewModel.errorMessage)
    }
}

#Preview {
    ServerView()
}
