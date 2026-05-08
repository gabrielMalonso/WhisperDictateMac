import Foundation

enum GroqClientError: LocalizedError, Equatable {
    case apiKeyMissing
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case requestFailed(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return String(localized: "Informe uma chave de API da Groq antes de usar esse modo.")
        case .invalidResponse:
            return String(localized: "A Groq retornou uma resposta inválida.")
        case .authenticationFailed:
            return String(localized: "A chave de API da Groq foi recusada.")
        case .rateLimited:
            return String(localized: "Limite da Groq atingido. Tente novamente em instantes.")
        case .requestFailed(_, let message):
            return message.isEmpty ? String(localized: "A chamada para a Groq falhou.") : message
        case .emptyResponse:
            return String(localized: "A Groq retornou texto vazio.")
        }
    }
}

final class GroqClient {
    private let baseURL: URL
    private let session: URLSession
    private let credentialStore: GroqCredentialStoring

    init(
        baseURL: URL = AppConfig.groqAPIBaseURL,
        session: URLSession = .shared,
        credentialStore: GroqCredentialStoring = GroqCredentialStore()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.credentialStore = credentialStore
    }

    func testAuthentication() async throws {
        var request = try authorizedRequest(path: "models")
        request.httpMethod = "GET"
        let (_, response) = try await session.data(for: request)
        try validate(response: response, data: Data())
    }

    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        translateToEnglish: Bool
    ) async throws -> String {
        let endpoint = translateToEnglish ? "audio/translations" : "audio/transcriptions"
        let fileData = try Data(contentsOf: audioURL)
        let boundary = "dictateoss-\(UUID().uuidString)"
        var request = try authorizedRequest(path: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fileData: fileData,
            fileName: audioURL.lastPathComponent,
            mimeType: mimeType(for: audioURL),
            fields: transcriptionFields(
                model: translateToEnglish ? "whisper-large-v3" : model,
                language: translateToEnglish ? nil : language,
                prompt: prompt
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(AudioTextResponse.self, from: data)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw GroqClientError.emptyResponse
        }
        return text
    }

    func chat(model: String, messages: [ChatMessage], temperature: Double = 0.1) async throws -> String {
        var request = try authorizedRequest(path: "chat/completions")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature
        ))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw GroqClientError.emptyResponse
        }
        return text
    }

    private func authorizedRequest(path: String) throws -> URLRequest {
        guard let apiKey = try credentialStore.apiKey(), !apiKey.isEmpty else {
            throw GroqClientError.apiKeyMissing
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AppConfig.defaultDictationTimeout
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GroqClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw GroqClientError.authenticationFailed
            }
            if http.statusCode == 429 {
                throw GroqClientError.rateLimited
            }
            let message = (try? JSONDecoder().decode(GroqErrorResponse.self, from: data).error.message) ?? ""
            throw GroqClientError.requestFailed(statusCode: http.statusCode, message: message)
        }
    }

    private func transcriptionFields(model: String, language: String?, prompt: String?) -> [String: String] {
        var fields = [
            "model": model,
            "response_format": "json",
            "temperature": "0"
        ]
        if let language, !language.isEmpty {
            fields["language"] = language
        }
        if let prompt, !prompt.isEmpty {
            fields["prompt"] = prompt
        }
        return fields
    }

    private func multipartBody(
        boundary: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String]
    ) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp4": "audio/mp4"
        case "mp3", "mpeg", "mpga": "audio/mpeg"
        case "ogg": "audio/ogg"
        case "wav": "audio/wav"
        case "webm": "audio/webm"
        case "flac": "audio/flac"
        default: "application/octet-stream"
        }
    }
}

struct ChatMessage: Codable, Equatable {
    let role: String
    let content: String
}

private struct AudioTextResponse: Decodable {
    let text: String
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct GroqErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
