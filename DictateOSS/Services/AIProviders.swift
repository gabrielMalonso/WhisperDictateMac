import Foundation

struct TranscriptionRequest {
    let audioURL: URL
    let language: String?
    let dictionaryTerms: [String]
    let translationRequested: Bool
}

struct TranscriptionProviderResult {
    let text: String
    let rawText: String?
}

protocol TranscriptionProvider {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionProviderResult
}

struct LLMProcessingRequest {
    let text: String
    let language: String
    let formattingOptions: FormattingOptions
    let translationRequested: Bool
    let translationTargetLanguage: String
}

protocol LLMProvider {
    func process(_ request: LLMProcessingRequest) async throws -> String
}

struct NoOpLLMProvider: LLMProvider {
    func process(_ request: LLMProcessingRequest) async throws -> String {
        request.text
    }
}

struct LocalWhisperProvider: TranscriptionProvider {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionProviderResult {
        let result = await LocalTranscriptionService.transcribe(
            audioURL: request.audioURL,
            language: request.language
        )
        switch result {
        case .success(let text):
            return TranscriptionProviderResult(text: text, rawText: nil)
        case .failure(let error):
            throw error
        }
    }
}

struct LocalLLMProvider: LLMProvider {
    private let client: OllamaClient

    init(model: String, baseURL: URL = AppConfig.ollamaAPIBaseURL) {
        self.client = OllamaClient(model: model, baseURL: baseURL)
    }

    func process(_ request: LLMProcessingRequest) async throws -> String {
        try await client.process(request)
    }
}

enum AIProviderFactory {
    static func transcriptionProvider(
        for kind: TranscriptionProviderKind,
        defaults: UserDefaultsProviding = UserDefaults.app,
        credentialStore: GroqCredentialStoring = GroqCredentialStore()
    ) -> any TranscriptionProvider {
        switch kind {
        case .local:
            return LocalWhisperProvider()
        case .groq:
            let model = defaults.string(forKey: MacAppKeys.groqWhisperModel) ?? AppConfig.defaultGroqWhisperModel
            return GroqTranscriptionProvider(model: model, credentialStore: credentialStore)
        }
    }
    static func llmProvider(
        for kind: LLMProviderKind,
        defaults: UserDefaultsProviding = UserDefaults.app,
        credentialStore: GroqCredentialStoring = GroqCredentialStore()
    ) -> any LLMProvider {
        switch kind {
        case .none:
            return NoOpLLMProvider()
        case .local:
            let model = defaults.string(forKey: MacAppKeys.localLLMModel) ?? AppConfig.defaultLocalLLMModel
            return LocalLLMProvider(model: model)
        case .groq:
            let model = defaults.string(forKey: MacAppKeys.groqLLMModel) ?? AppConfig.defaultGroqLLMModel
            return GroqLLMProvider(model: model, credentialStore: credentialStore)
        }
    }
}
