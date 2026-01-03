//
import Foundation

// shared service constants
enum ServiceInfo {
    static let host = "127.0.0.1"
    static let port = 12345
    static let servicePrefix = "InferRing"
    @UserDefaultsKey("bonjourName")
    static var bonjourName = "\(servicePrefix)-\(UUID().uuidString)"

    
}
