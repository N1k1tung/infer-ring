//
import Foundation

public enum RingError: LocalizedError {
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let message):
            return "Ring Error: \(message)"
        }
    }
}
