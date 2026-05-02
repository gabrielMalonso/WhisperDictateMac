import Foundation

protocol UserDefaultsProviding {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func float(forKey defaultName: String) -> Float
    func double(forKey defaultName: String) -> Double
    func data(forKey defaultName: String) -> Data?
    @discardableResult func synchronize() -> Bool
}

extension UserDefaults: UserDefaultsProviding {}
