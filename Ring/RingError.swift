//
import Foundation

public enum RingError: Error {
    case failed(String)

    public var localizedDescription: String? {
        switch self {
        case .failed(let message):
            return "Ring Error: \(message)"
        }
    }
}
