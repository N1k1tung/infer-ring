//

import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func nilIfEmpty() -> String? {
        return isEmpty ? nil : self
    }
}

func dprint(_ item: Any) {
#if DEBUG
    print(item)
#endif
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
