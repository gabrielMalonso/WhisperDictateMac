import Foundation

enum AppSettings {
    static let suiteName = "com.gmalonso.whisper-dictate-mac"

    static let mlxExecutablePathKey = "mlxExecutablePath"
    static let mlxModelKey = "mlxModel"
    static let languageKey = "language"
    static let restoreClipboardKey = "restoreClipboard"

    static let defaultMLXExecutablePath = "\(NSHomeDirectory())/.local/bin/mlx_whisper"
    static let defaultMLXModel = "mlx-community/whisper-large-v3-turbo"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            mlxExecutablePathKey: defaultMLXExecutablePath,
            mlxModelKey: defaultMLXModel,
            languageKey: "pt",
            restoreClipboardKey: true
        ])
    }
}
