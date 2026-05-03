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

enum OllamaLocalLLMError: LocalizedError, Equatable {
    case invalidEndpoint
    case remoteEndpointNotAllowed
    case emptyResponse
    case httpError(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return String(localized: "Endpoint do Ollama inválido.")
        case .remoteEndpointNotAllowed:
            return String(localized: "Somente endpoints locais são permitidos.")
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

    private func sendJSON<T: Encodable>(
        _ body: T?,
        to url: URL,
        timeout: Double,
        method: String
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaLocalLLMError.decodingFailed
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OllamaLocalLLMError.httpError(httpResponse.statusCode, body)
        }
        return data
    }
}
