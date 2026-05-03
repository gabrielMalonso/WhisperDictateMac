import Foundation

protocol LocalLLMClient {
    func complete(
        systemPrompt: String,
        userText: String,
        configuration: LocalLLMConfiguration
    ) async throws -> String

    func installedModels(configuration: LocalLLMConfiguration) async throws -> [String]
}

struct LocalLLMConfiguration: Equatable {
    var isEnabled: Bool
    var endpoint: String
    var model: String
    var timeoutSeconds: Double
    var minCharsToFormat: Int
    var temperature: Double

    static let defaultEndpoint = "http://localhost:11434"
    static let defaultModel = "qwen2.5:3b"
    static let defaultTimeoutSeconds = 30.0
    static let defaultMinCharsToFormat = 100
    static let defaultTemperature = 0.3

    static let `default` = LocalLLMConfiguration(
        isEnabled: true,
        endpoint: defaultEndpoint,
        model: defaultModel,
        timeoutSeconds: defaultTimeoutSeconds,
        minCharsToFormat: defaultMinCharsToFormat,
        temperature: defaultTemperature
    )

    static func load(from defaults: UserDefaultsProviding = UserDefaults.app) -> LocalLLMConfiguration {
        let enabledValue = defaults.object(forKey: MacAppKeys.localFormattingLLMEnabled) as? Bool
        let endpoint = defaults.string(forKey: MacAppKeys.localFormattingLLMEndpoint) ?? defaultEndpoint
        let model = defaults.string(forKey: MacAppKeys.localFormattingLLMModel) ?? defaultModel
        let timeout = defaults.double(forKey: MacAppKeys.localFormattingLLMTimeoutSeconds)
        let minChars = defaults.object(forKey: MacAppKeys.localFormattingMinChars) == nil
            ? defaultMinCharsToFormat
            : defaults.integer(forKey: MacAppKeys.localFormattingMinChars)

        return LocalLLMConfiguration(
            isEnabled: enabledValue ?? true,
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultEndpoint : endpoint,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model,
            timeoutSeconds: timeout > 0 ? timeout : defaultTimeoutSeconds,
            minCharsToFormat: minChars >= 0 ? minChars : defaultMinCharsToFormat,
            temperature: defaultTemperature
        )
    }

    var endpointURL: URL? {
        URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isLocalEndpoint: Bool {
        guard let url = endpointURL, let host = url.host?.lowercased() else {
            return false
        }
        return ["localhost", "127.0.0.1", "::1"].contains(host)
    }
}

struct OllamaModelPullProgress: Equatable {
    let status: String
    let digest: String?
    let total: Int64?
    let completed: Int64?

    var fractionCompleted: Double? {
        guard let total, total > 0, let completed else {
            return nil
        }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

enum OllamaLocalLLMError: LocalizedError, Equatable {
    case invalidEndpoint
    case invalidModelName
    case ollamaNotFound
    case remoteEndpointNotAllowed
    case connectionFailed(String)
    case emptyResponse
    case httpError(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return String(localized: "Endpoint do Ollama inválido.")
        case .invalidModelName:
            return String(localized: "Nome do modelo inválido.")
        case .ollamaNotFound:
            return String(localized: "Não encontrei o Ollama. Instale com `brew install ollama` ou abra o app Ollama.")
        case .remoteEndpointNotAllowed:
            return String(localized: "Somente endpoints locais são permitidos.")
        case .connectionFailed(let endpoint):
            return String(localized: "Não consegui conectar ao Ollama em \(endpoint). Abra o Ollama ou rode `ollama serve` e tente novamente.")
        case .emptyResponse:
            return String(localized: "A LLM local retornou uma resposta vazia.")
        case .httpError(let status, let body):
            return body.isEmpty
                ? String(localized: "Ollama retornou HTTP \(status).")
                : String(localized: "Ollama retornou HTTP \(status): \(body)")
        case .decodingFailed:
            return String(localized: "Não foi possível ler a resposta do Ollama.")
        }
    }
}

struct OllamaLocalLLMClient: LocalLLMClient {
    private struct ChatMessage: Codable, Equatable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable, Equatable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let options: Options

        struct Options: Codable, Equatable {
            let temperature: Double
        }
    }

    private struct ChatResponse: Decodable {
        let message: ChatMessage?
        let response: String?
        let error: String?
    }

    private struct TagsResponse: Decodable {
        let models: [Model]

        struct Model: Decodable {
            let name: String
        }
    }

    private struct PullRequest: Encodable, Equatable {
        let name: String
        let stream: Bool
    }

    private struct PullResponse: Decodable {
        let status: String?
        let digest: String?
        let total: Int64?
        let completed: Int64?
        let error: String?
    }

    private struct DeleteRequest: Encodable, Equatable {
        let name: String
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(
        systemPrompt: String,
        userText: String,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        let requestBody = ChatRequest(
            model: configuration.model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: LocalFormattingPostProcessor.wrapTranscription(userText))
            ],
            stream: false,
            options: .init(temperature: configuration.temperature)
        )
        let data = try await sendJSON(
            requestBody,
            to: try apiURL(path: "api/chat", configuration: configuration),
            timeout: configuration.timeoutSeconds,
            method: "POST"
        )
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw OllamaLocalLLMError.decodingFailed
        }
        if let error = decoded.error, !error.isEmpty {
            throw OllamaLocalLLMError.httpError(200, error)
        }
        let content = (decoded.message?.content ?? decoded.response ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw OllamaLocalLLMError.emptyResponse
        }
        return content
    }

    func installedModels(configuration: LocalLLMConfiguration) async throws -> [String] {
        let data = try await sendJSON(
            Optional<String>.none,
            to: try apiURL(path: "api/tags", configuration: configuration),
            timeout: configuration.timeoutSeconds,
            method: "GET"
        )
        guard let decoded = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            throw OllamaLocalLLMError.decodingFailed
        }
        return decoded.models.map(\.name).sorted()
    }

    func pullModel(
        named modelName: String,
        configuration: LocalLLMConfiguration,
        progress: @escaping (OllamaModelPullProgress) async -> Void = { _ in }
    ) async throws {
        let modelName = try normalizedModelName(modelName)
        let body = PullRequest(name: modelName, stream: true)
        let request = try makeJSONRequest(
            body,
            to: apiURL(path: "api/pull", configuration: configuration),
            timeout: max(configuration.timeoutSeconds, 3_600),
            method: "POST"
        )

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw mapNetworkError(error, endpoint: configuration.endpoint)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaLocalLLMError.decodingFailed
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            var body = ""
            do {
                for try await line in bytes.lines {
                    body += line
                }
            } catch let error as URLError {
                throw mapNetworkError(error, endpoint: configuration.endpoint)
            }
            throw OllamaLocalLLMError.httpError(httpResponse.statusCode, body)
        }

        do {
            for try await line in bytes.lines {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                guard let data = line.data(using: .utf8),
                      let decoded = try? JSONDecoder().decode(PullResponse.self, from: data) else {
                    throw OllamaLocalLLMError.decodingFailed
                }
                if let error = decoded.error, !error.isEmpty {
                    throw OllamaLocalLLMError.httpError(200, error)
                }
                await progress(
                    OllamaModelPullProgress(
                        status: decoded.status ?? String(localized: "Baixando modelo"),
                        digest: decoded.digest,
                        total: decoded.total,
                        completed: decoded.completed
                    )
                )
            }
        } catch let error as URLError {
            throw mapNetworkError(error, endpoint: configuration.endpoint)
        }
    }

    func deleteModel(named modelName: String, configuration: LocalLLMConfiguration) async throws {
        let modelName = try normalizedModelName(modelName)
        _ = try await sendJSON(
            DeleteRequest(name: modelName),
            to: try apiURL(path: "api/delete", configuration: configuration),
            timeout: configuration.timeoutSeconds,
            method: "DELETE"
        )
    }

    private func apiURL(path: String, configuration: LocalLLMConfiguration) throws -> URL {
        guard configuration.isLocalEndpoint else {
            throw configuration.endpointURL == nil
                ? OllamaLocalLLMError.invalidEndpoint
                : OllamaLocalLLMError.remoteEndpointNotAllowed
        }
        guard let baseURL = configuration.endpointURL else {
            throw OllamaLocalLLMError.invalidEndpoint
        }
        return baseURL.appendingPathComponent(path)
    }

    private func normalizedModelName(_ modelName: String) throws -> String {
        let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OllamaLocalLLMError.invalidModelName
        }
        return trimmed
    }

    private func makeJSONRequest<T: Encodable>(
        _ body: T?,
        to url: URL,
        timeout: Double,
        method: String
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    private func sendJSON<T: Encodable>(
        _ body: T?,
        to url: URL,
        timeout: Double,
        method: String
    ) async throws -> Data {
        let request = try makeJSONRequest(body, to: url, timeout: timeout, method: method)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapNetworkError(error, endpoint: url.absoluteString)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaLocalLLMError.decodingFailed
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OllamaLocalLLMError.httpError(httpResponse.statusCode, body)
        }
        return data
    }

    private func mapNetworkError(_ error: URLError, endpoint: String) -> Error {
        switch error.code {
        case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost:
            return OllamaLocalLLMError.connectionFailed(endpoint)
        default:
            return error
        }
    }
}

enum OllamaServerLauncher {
    static var isInstalled: Bool {
        ExecutableResolver.resolve("ollama", fallbackName: "ollama") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Ollama.app")
    }

    static func start() throws {
        var startedSomething = false

        if let openPath = ExecutableResolver.resolve("open", fallbackName: "open") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: openPath)
            process.arguments = ["-a", "Ollama"]
            try? process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                startedSomething = true
            }
        }

        if let ollamaPath = ExecutableResolver.resolve("ollama", fallbackName: "ollama") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ollamaPath)
            process.arguments = ["serve"]
            try process.run()
            startedSomething = true
        }

        if !startedSomething {
            throw OllamaLocalLLMError.ollamaNotFound
        }
    }
}

enum OllamaInstaller {
    static let officialDownloadURL = URL(string: "https://ollama.com/download")!

    static var canInstallWithHomebrew: Bool {
        ExecutableResolver.resolve("brew", fallbackName: "brew") != nil
    }

    static func installWithHomebrew(progress: @escaping (String) async -> Void = { _ in }) async throws {
        guard let brewPath = ExecutableResolver.resolve("brew", fallbackName: "brew") else {
            throw OllamaLocalLLMError.ollamaNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "--cask", "ollama"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let handle = pipe.fileHandleForReading
        while process.isRunning {
            let data = handle.availableData
            if !data.isEmpty, let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                await progress(line)
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let remaining = handle.availableData
        if !remaining.isEmpty, let line = String(data: remaining, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
            await progress(line)
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OllamaLocalLLMError.httpError(Int(process.terminationStatus), String(localized: "Falha ao instalar Ollama via Homebrew."))
        }
    }
}
