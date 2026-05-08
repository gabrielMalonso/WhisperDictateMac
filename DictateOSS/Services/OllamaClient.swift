import Foundation

enum OllamaClientError: LocalizedError {
    case unavailable
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "Ollama local não respondeu. Abra o Ollama ou escolha outro modo.")
        case .requestFailed(let message):
            return message.isEmpty ? String(localized: "Ollama local falhou.") : message
        case .emptyResponse:
            return String(localized: "Ollama retornou texto vazio.")
        }
    }
}

final class OllamaClient {
    private let model: String
    private let baseURL: URL
    private let session: URLSession

    init(model: String, baseURL: URL = AppConfig.ollamaAPIBaseURL, session: URLSession = .shared) {
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }

    func process(_ request: LLMProcessingRequest) async throws -> String {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.defaultDictationTimeout
        urlRequest.httpBody = try JSONEncoder().encode(OllamaChatRequest(
            model: model,
            messages: PromptBuilder.messages(for: request),
            stream: false
        ))

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw OllamaClientError.unavailable
            }
            guard (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? ""
                throw OllamaClientError.requestFailed(message)
            }
            let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            let text = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw OllamaClientError.emptyResponse
            }
            return text
        } catch let error as OllamaClientError {
            throw error
        } catch {
            throw OllamaClientError.unavailable
        }
    }
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
}

private struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }
    let message: Message
}
