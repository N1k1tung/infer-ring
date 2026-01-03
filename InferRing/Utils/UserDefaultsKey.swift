//

import Foundation

@propertyWrapper
struct UserDefaultsKey<T> {
    private let key: String
    private let defaultValue: T

    init(wrappedValue defaultValue: T, _ key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }

    var wrappedValue: T {
        get {
            let value = UserDefaults.standard.object(forKey: key) as? T
            if let value {
                return value
            }
            UserDefaults.standard.setValue(defaultValue, forKey: key)
            return defaultValue
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }
}
