import Foundation

private nonisolated(unsafe) var _appDefaults: UserDefaults = .standard

extension UserDefaults {
    static var app: UserDefaults {
        get { _appDefaults }
        set { _appDefaults = newValue }
    }
}
