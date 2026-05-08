import Foundation

enum AppConfig {
    static let appBundleId = "com.gmalonso.dictate-oss"

    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid URL string: \(string)")
        }
        return url
    }

    private static func makeLegalURL(_ string: String) -> URL {
        let url = makeURL(string)
        #if DEBUG
        let isHTTPS = url.scheme?.lowercased() == "https"
        let hasHost = !(url.host?.isEmpty ?? true)
        if !isHTTPS || !hasHost {
            assertionFailure("Legal URL must be https and include host: \(string)")
        }
        #endif
        return url
    }

    // MARK: - Open Source Links

    static let termsOfUseURL = makeLegalURL("https://github.com/gabrielMalonso/WhisperDictateMac")
    static let privacyPolicyURL = makeLegalURL("https://github.com/gabrielMalonso/WhisperDictateMac")

    // MARK: - App Links

    static let urlScheme = "dictate-oss"

    // MARK: - Local Usage

    static let defaultWeeklyUsageGoal = 100_000

    // MARK: - Dictation

    static let maxRecordingDuration: TimeInterval = 240  // 4 minutes
    static let recordingWarningThreshold: Int = 15  // seconds before limit to show warning
    static let defaultDictationTimeout: TimeInterval = 240  // 4 minutes
    static let defaultClipboardRestoreDelayMs = 200
    static let defaultMLXModel = "mlx-community/whisper-large-v3-turbo"
    static let defaultGroqWhisperModel = "whisper-large-v3-turbo"
    static let defaultGroqLLMModel = "openai/gpt-oss-20b"
    static let defaultLocalLLMModel = "llama3.1"
    static let groqAPIBaseURL = makeURL("https://api.groq.com/openai/v1")
    static let ollamaAPIBaseURL = makeURL("http://localhost:11434")

    static var defaultMLXExecutablePath: String {
        ExecutableResolver.resolve("mlx_whisper", fallbackName: "mlx_whisper")
            ?? "\(NSHomeDirectory())/.local/bin/mlx_whisper"
    }
}
