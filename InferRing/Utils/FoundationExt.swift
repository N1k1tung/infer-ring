//

import Foundation

infix operator ~!~ : AssignmentPrecedence

func ~!~<T:AnyObject>(left:T, right:(T)->()) -> T {
    right(left)
    return left
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func nilIfEmpty() -> String? {
        return isEmpty ? nil : self
    }
}

func dprint(_ item: Any?) {
#if DEBUG
    if let item {
        print(item)
    }
#endif
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension JSONDecoder {
    static let `default` = JSONDecoder() ~!~ {
        $0.dateDecodingStrategy = .millisecondsSince1970
    }
}

extension JSONEncoder {
    static let `default` = JSONEncoder() ~!~ {
        $0.dateEncodingStrategy = .millisecondsSince1970
    }
}

extension Int {
    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}
