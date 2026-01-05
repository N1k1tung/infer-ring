//
import SwiftUI

extension Binding {
    func map<T>(transform: @escaping (Value) -> T, setter: ((T) -> Void)? = nil) -> Binding<T> {
        Binding<T> {
            transform(wrappedValue)
        } set: {
            setter?($0)
        }
    }
}

extension View {
    func errorAlert(_ binding: Binding<String?>) -> some View {
        self.alert(isPresented: binding.map { $0 != nil }, content: {
            Alert(title: Text("Error"), message: Text(binding.wrappedValue ?? ""), dismissButton: .default(Text("OK")) {
                binding.wrappedValue = nil
            })
        })
    }
}
