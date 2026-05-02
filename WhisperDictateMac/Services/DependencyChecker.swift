import Foundation

struct DependencyStatus: Equatable {
    var mlxExecutablePath: String?
    var ffmpegPath: String?
    var model: String

    var missingItems: [String] {
        var items: [String] = []

        if mlxExecutablePath == nil {
            items.append("mlx_whisper")
        }

        if ffmpegPath == nil {
            items.append("ffmpeg")
        }

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("modelo MLX")
        }

        return items
    }

    var isReady: Bool {
        missingItems.isEmpty
    }
}

enum DependencyChecker {
    static func check(configuration: WhisperConfiguration = .current()) -> DependencyStatus {
        DependencyStatus(
            mlxExecutablePath: ExecutableResolver.resolve(configuration.executablePath, fallbackName: "mlx_whisper"),
            ffmpegPath: ExecutableResolver.resolve("ffmpeg"),
            model: configuration.model
        )
    }
}
