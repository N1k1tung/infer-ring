//

import Foundation

struct DI {
    private init() {}
    private var storage: [String: Any] = [:]

    private mutating func setObject<T>(_ object: T) {
        storage[String(describing: T.self)] = object
    }
    
    fileprivate subscript<T>(key: T.Type) -> T? {
        storage[String(describing: key)] as? T
    }

    fileprivate static var shared = DI()
    static func register<T>(_ object: T) {
        DI.shared.setObject(object)
    }
}

@propertyWrapper
struct Inject<T> {
    var wrappedValue: T? {
        DI.shared[T.self]
    }
}
