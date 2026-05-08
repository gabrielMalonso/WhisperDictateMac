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
    case transcriptMissing(expectedPath: String, processOutput: String, generatedFiles: [String])

    var errorDescription: String? {
        switch self {
        case .executableMissing(let path):
            return String(localized: "Executável do MLX Whisper não encontrado: \(path)")
        case .modelMissing:
            return String(localized: "Configure o modelo MLX antes de transcrever.")
        case .processFailed(let output):
            return output.isEmpty ? String(localized: "MLX Whisper falhou sem mensagem útil.") : output
        case .transcriptMissing(let expectedPath, let processOutput, let generatedFiles):
            let files = generatedFiles.isEmpty ? "nenhum arquivo encontrado" : generatedFiles.joined(separator: ", ")
            let output = processOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return String(localized: "MLX Whisper terminou, mas não gerou transcrição. Esperado: \(expectedPath). Gerados: \(files).")
            }
            return String(localized: "MLX Whisper terminou, mas não gerou transcrição. Esperado: \(expectedPath). Gerados: \(files). Saída: \(output)")
        }
    }
}

struct MLXWhisperCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
    let outputDirectoryURL: URL
    let outputTextURL: URL
}

final class MLXWhisperTranscriber {
    private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "MLXWhisper")

    func transcribe(
        audioURL: URL,
        configuration: MLXWhisperConfiguration = .current()
    ) async throws -> String {
        let command = try makeCommand(audioURL: audioURL, configuration: configuration)

        logger.info("MLX command: \(self.render(command), privacy: .public)")

        let output = try await run(command)
        let generatedFiles = generatedFileNames(in: command.outputDirectoryURL)

        logger.info(
            """
            MLX finished: status=\(output.terminationStatus), \
            outputFiles=\(generatedFiles.joined(separator: ", "), privacy: .public), \
            processOutput=\(self.loggable(output.text), privacy: .public)
            """
        )

        if !output.exitOK {
            throw MLXWhisperError.processFailed(output.text)
        }

        let transcriptURL: URL
        if FileManager.default.fileExists(atPath: command.outputTextURL.path) {
            transcriptURL = command.outputTextURL
        } else if let fallbackURL = firstTextOutput(in: command.outputDirectoryURL) {
            logger.warning(
                """
                Expected transcript missing at \(command.outputTextURL.path, privacy: .public); \
                using fallback \(fallbackURL.path, privacy: .public)
                """
            )
            transcriptURL = fallbackURL
        } else {
            throw MLXWhisperError.transcriptMissing(
                expectedPath: command.outputTextURL.path,
                processOutput: output.text,
                generatedFiles: generatedFiles
            )
        }
        defer {
            try? FileManager.default.removeItem(at: command.outputDirectoryURL)
        }

        let text = try String(contentsOf: transcriptURL, encoding: .utf8)
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

        let model = ExecutableResolver.expandedPath(configuration.model)
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
            "--task", "transcribe",
            "--verbose", "False",
            "--temperature", "0",
            "--condition-on-previous-text", "False"
        ]

        let language = configuration.language.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLanguage = resolvedLanguage(for: language)
        if !resolvedLanguage.isEmpty {
            arguments.append(contentsOf: ["--language", resolvedLanguage])
        }

        return MLXWhisperCommand(
            executableURL: URL(fileURLWithPath: executablePath),
            arguments: arguments,
            outputDirectoryURL: outputDirectory,
            outputTextURL: outputTextURL
        )
    }

    private struct ProcessOutput {
        let terminationStatus: Int32
        let exitOK: Bool
        let text: String
    }

    private func run(_ command: MLXWhisperCommand) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = command.executableURL
            process.arguments = command.arguments
            process.environment = processEnvironment()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessOutput(
                    terminationStatus: process.terminationStatus,
                    exitOK: process.terminationStatus == 0,
                    text: text
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let searchPath = (
            environment["PATH", default: ""]
                .split(separator: ":")
                .map(String.init)
                + ExecutableResolver.commonSearchDirectories
        )
        environment["PATH"] = Array(NSOrderedSet(array: searchPath)).compactMap { $0 as? String }.joined(separator: ":")
        environment["PYTHONUNBUFFERED"] = "1"
        return environment
    }

    private func resolvedLanguage(for language: String) -> String {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized == "auto" {
            return ""
        }
        return normalized
    }

    private func generatedFileNames(in directoryURL: URL) -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files
            .map(\.lastPathComponent)
            .sorted()
    }

    private func firstTextOutput(in directoryURL: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        return files
            .filter { $0.pathExtension.lowercased() == "txt" }
            .min { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func render(_ command: MLXWhisperCommand) -> String {
        ([command.executableURL.path] + command.arguments)
            .map { argument in
                argument.contains(" ") ? "\"\(argument)\"" : argument
            }
            .joined(separator: " ")
    }

    private func loggable(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        guard flattened.count > 1200 else { return flattened }
        return String(flattened.prefix(1200)) + "..."
    }
}
