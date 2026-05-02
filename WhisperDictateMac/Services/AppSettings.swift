import Foundation

enum AppSettings {
    static let mlxExecutablePathKey = "mlxExecutablePath"
    static let mlxModelKey = "mlxModel"
    static let languageKey = "language"
    static let restoreClipboardKey = "restoreClipboard"

    static var defaultMLXExecutablePath: String {
        ExecutableResolver.resolve("mlx_whisper", fallbackName: "mlx_whisper") ?? "\(NSHomeDirectory())/.local/bin/mlx_whisper"
    }
    static let defaultMLXModel = "mlx-community/whisper-large-v3-turbo"

    static var defaults: UserDefaults {
        .standard
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
