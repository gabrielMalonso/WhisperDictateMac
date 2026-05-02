import Foundation
import os

struct MLXWhisperConfiguration: Equatable {
    var executablePath: String
    var model: String
    var language: String

    static func current(defaults: UserDefaults = .app) -> MLXWhisperConfiguration {
        MLXWhisperConfiguration(
            executablePath: defaults.string(forKey: MacAppKeys.mlxExecutablePath) ?? AppConfig.defaultMLXExecutablePath,
            model: defaults.string(forKey: MacAppKeys.mlxModel) ?? AppConfig.defaultMLXModel,
            language: defaults.string(forKey: MacAppKeys.transcriptionLanguage) ?? DeviceLanguageMapper.deviceDefault
        )
    }
}

enum MLXWhisperError: LocalizedError, Equatable {
    case executableMissing(String)
    case modelMissing
    case processFailed(String)
    case transcriptMissing

    var errorDescription: String? {
        switch self {
        case .executableMissing(let path):
            return "Executavel do MLX Whisper nao encontrado: \(path)"
        case .modelMissing:
            return "Configure o modelo MLX antes de transcrever."
        case .processFailed(let output):
            return output.isEmpty ? "MLX Whisper falhou sem mensagem util." : output
        case .transcriptMissing:
            return "MLX Whisper terminou, mas nao gerou transcricao."
        }
    }
}

struct MLXWhisperCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
    let outputTextURL: URL
}

final class MLXWhisperTranscriber {
    private let logger = Logger(subsystem: "com.gmalonso.whisper-dictate-mac", category: "MLXWhisper")

    func transcribe(
        audioURL: URL,
        configuration: MLXWhisperConfiguration = .current()
    ) async throws -> String {
        let command = try makeCommand(audioURL: audioURL, configuration: configuration)
        defer {
            try? FileManager.default.removeItem(at: command.outputTextURL.deletingLastPathComponent())
        }

        let output = try await run(command)

        if !output.exitOK {
            throw MLXWhisperError.processFailed(output.text)
        }

        guard FileManager.default.fileExists(atPath: command.outputTextURL.path) else {
            throw MLXWhisperError.transcriptMissing
        }

        let text = try String(contentsOf: command.outputTextURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        logger.info("MLX Whisper completed with \(text.count) chars")
        return text
    }

    func makeCommand(audioURL: URL, configuration: MLXWhisperConfiguration) throws -> MLXWhisperCommand {
        let requestedExecutable = configuration.executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let executablePath = ExecutableResolver.resolve(requestedExecutable, fallbackName: "mlx_whisper") else {
            let expandedExecutable = ExecutableResolver.expandedPath(requestedExecutable.isEmpty ? "mlx_whisper" : requestedExecutable)
            throw MLXWhisperError.executableMissing(expandedExecutable)
        }

        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw MLXWhisperError.modelMissing
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-dictate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outputName = "transcript"
        let outputTextURL = outputDirectory.appendingPathComponent(outputName).appendingPathExtension("txt")

        var arguments = [
            audioURL.path,
            "--model", model,
            "--output-dir", outputDirectory.path,
            "--output-name", outputName,
            "--output-format", "txt",
            "--verbose", "False"
        ]

        let language = configuration.language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty, language.lowercased() != "auto" {
            arguments.append(contentsOf: ["--language", language])
        }

        return MLXWhisperCommand(
            executableURL: URL(fileURLWithPath: executablePath),
            arguments: arguments,
            outputTextURL: outputTextURL
        )
    }

    private struct ProcessOutput {
        let exitOK: Bool
        let text: String
    }

    private func run(_ command: MLXWhisperCommand) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = command.executableURL
            process.arguments = command.arguments
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessOutput(exitOK: process.terminationStatus == 0, text: text))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
