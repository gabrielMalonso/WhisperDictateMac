import Foundation
import os

private let logger = Logger(subsystem: "com.gmalonso.whisper-dictate-mac", category: "LocalTranscription")

enum LocalTranscriptionService {

    // MARK: - Error

    enum LocalTranscriptionError: LocalizedError {
        case notAvailable
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return String(localized: "MLX Whisper não está disponível neste Mac.")
            case .recognitionFailed(let message):
                return message.isEmpty
                    ? String(localized: "Falha na transcrição local.")
                    : message
            }
        }
    }

    // MARK: - Public API

    /// Transcribes an audio file using the local MLX Whisper CLI.
    /// Returns the recognized text or a typed error.
    static func transcribe(audioURL: URL, language: String?) async -> Result<String, LocalTranscriptionError> {
        var configuration = MLXWhisperConfiguration.current()
        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configuration.language = language
        }

        logger.info("Starting MLX transcription for \(audioURL.lastPathComponent), language: \(configuration.language)")

        do {
            let text = try await MLXWhisperTranscriber().transcribe(audioURL: audioURL, configuration: configuration)
            return .success(text)
        } catch let error as MLXWhisperError {
            logger.error("MLX Whisper failed: \(error.localizedDescription)")
            if case .executableMissing = error {
                return .failure(.notAvailable)
            }
            return .failure(.recognitionFailed(error.localizedDescription))
        } catch {
            logger.error("Local transcription failed: \(error.localizedDescription)")
            return .failure(.recognitionFailed(error.localizedDescription))
        }
    }

    static func isAvailable(for language: String?) -> Bool {
        let configuration = MLXWhisperConfiguration.current()
        return ExecutableResolver.resolve(configuration.executablePath, fallbackName: "mlx_whisper") != nil
    }
}
