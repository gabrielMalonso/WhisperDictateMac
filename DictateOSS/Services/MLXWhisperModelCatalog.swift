import Foundation

struct MLXWhisperModelPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let approximateSize: String
}

enum MLXWhisperModelCatalog {
    static let presets: [MLXWhisperModelPreset] = [
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-large-v3-turbo",
            name: "Large v3 Turbo",
            detail: String(localized: "Recomendado para uso diário. Equilibra boa precisão, velocidade e consumo de recursos."),
            approximateSize: "1.61 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-large-v3-mlx",
            name: "Large v3",
            detail: String(localized: "Maior precisão, com processamento mais lento. Indicado quando qualidade é prioridade."),
            approximateSize: "~3 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-small-mlx",
            name: "Small",
            detail: String(localized: "Modelo intermediário para transcrições leves, testes e Macs com recursos limitados."),
            approximateSize: "~1 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-tiny",
            name: "Tiny",
            detail: String(localized: "Opção mínima para validar a configuração. Não é indicada para transcrições finais."),
            approximateSize: "74 MB"
        )
    ]

    static func preset(for model: String) -> MLXWhisperModelPreset? {
        presets.first { $0.id == model.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func isInstalled(_ model: String) -> Bool {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("/") == false {
            return false
        }

        let expanded = ExecutableResolver.expandedPath(trimmed)
        if FileManager.default.fileExists(atPath: expanded) {
            return true
        }

        guard let cacheURL = huggingFaceCacheURL(for: trimmed) else {
            return false
        }

        let snapshotsURL = cacheURL.appendingPathComponent("snapshots", isDirectory: true)
        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return !snapshots.isEmpty
    }

    static func installStateLabel(for model: String) -> String {
        if isInstalled(model) {
            return String(localized: "Instalado")
        }
        return String(localized: "Baixa no primeiro uso")
    }

    static func huggingFaceCachePath(for model: String) -> String? {
        huggingFaceCacheURL(for: model)?.path
    }

    static func huggingFaceCacheURL(for model: String) -> URL? {
        let parts = model.split(separator: "/")
        guard parts.count == 2 else { return nil }

        let hubRoot: URL
        if let hfHubCache = ProcessInfo.processInfo.environment["HUGGINGFACE_HUB_CACHE"], !hfHubCache.isEmpty {
            hubRoot = URL(fileURLWithPath: ExecutableResolver.expandedPath(hfHubCache), isDirectory: true)
        } else if let hfHome = ProcessInfo.processInfo.environment["HF_HOME"], !hfHome.isEmpty {
            hubRoot = URL(fileURLWithPath: ExecutableResolver.expandedPath(hfHome), isDirectory: true)
                .appendingPathComponent("hub", isDirectory: true)
        } else {
            hubRoot = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent(".cache/huggingface/hub", isDirectory: true)
        }

        let cacheName = "models--\(parts[0])--\(parts[1])"
        return hubRoot.appendingPathComponent(cacheName, isDirectory: true)
    }
}

enum MLXWhisperModelManagementError: LocalizedError {
    case invalidRemoteModel(String)
    case executableMissing(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRemoteModel(let model):
            return String(localized: "Modelo remoto inválido: \(model)")
        case .executableMissing(let path):
            return String(localized: "Executável do MLX Whisper não encontrado: \(path)")
        case .processFailed(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? String(localized: "Download do modelo falhou sem mensagem útil.") : trimmed
        }
    }
}

enum MLXWhisperModelManager {
    static func download(model: String, executablePath: String) async throws {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MLXWhisperModelCatalog.huggingFaceCacheURL(for: trimmedModel) != nil else {
            throw MLXWhisperModelManagementError.invalidRemoteModel(trimmedModel)
        }

        let requestedExecutable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolvedExecutable = ExecutableResolver.resolve(requestedExecutable, fallbackName: "mlx_whisper") else {
            let expandedExecutable = ExecutableResolver.expandedPath(requestedExecutable.isEmpty ? "mlx_whisper" : requestedExecutable)
            throw MLXWhisperModelManagementError.executableMissing(expandedExecutable)
        }

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-dictate-model-download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workDirectory)
        }

        let audioURL = workDirectory.appendingPathComponent("silence.wav")
        try writeSilentWAV(to: audioURL)

        let outputDirectory = workDirectory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: resolvedExecutable)
        process.arguments = [
            audioURL.path,
            "--model", trimmedModel,
            "--output-dir", outputDirectory.path,
            "--output-name", "preload",
            "--output-format", "txt",
            "--task", "transcribe",
            "--verbose", "False",
            "--temperature", "0",
            "--condition-on-previous-text", "False",
            "--language", "en"
        ]
        process.environment = processEnvironment()
        process.standardOutput = pipe
        process.standardError = pipe

        let output = try await run(process: process, pipe: pipe)
        guard output.terminationStatus == 0 else {
            throw MLXWhisperModelManagementError.processFailed(output.text)
        }
    }

    static func delete(model: String) throws {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cacheURL = MLXWhisperModelCatalog.huggingFaceCacheURL(for: trimmedModel) else {
            throw MLXWhisperModelManagementError.invalidRemoteModel(trimmedModel)
        }

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: cacheURL)
    }

    private struct ProcessOutput {
        let terminationStatus: Int32
        let text: String
    }

    private static func run(process: Process, pipe: Pipe) async throws -> ProcessOutput {
        let outputBuffer = ProcessOutputBuffer()
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputBuffer.append(data)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                fileHandle.readabilityHandler = nil
                outputBuffer.append(fileHandle.readDataToEndOfFile())
                continuation.resume(returning: ProcessOutput(
                    terminationStatus: process.terminationStatus,
                    text: outputBuffer.text
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func processEnvironment() -> [String: String] {
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

    private static func writeSilentWAV(to url: URL) throws {
        let sampleRate: UInt32 = 16_000
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let seconds: UInt32 = 1
        let sampleCount = sampleRate * seconds
        let dataSize = sampleCount * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndianUInt32(36 + dataSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndianUInt32(16)
        data.appendLittleEndianUInt16(1)
        data.appendLittleEndianUInt16(channelCount)
        data.appendLittleEndianUInt32(sampleRate)
        data.appendLittleEndianUInt32(byteRate)
        data.appendLittleEndianUInt16(blockAlign)
        data.appendLittleEndianUInt16(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndianUInt32(dataSize)
        data.append(Data(repeating: 0, count: Int(dataSize)))

        try data.write(to: url, options: .atomic)
    }
}

private final class ProcessOutputBuffer {
    private let lock = NSLock()
    private var data = Data()
    private let maxLength = 16_384

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        if data.count < maxLength {
            data.append(newData.prefix(maxLength - data.count))
        }
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndianUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
