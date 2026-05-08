import Foundation

struct GroqTranscriptionProvider: TranscriptionProvider {
    private let model: String
    private let client: GroqClient

    init(
        model: String,
        client: GroqClient? = nil,
        credentialStore: GroqCredentialStoring = GroqCredentialStore()
    ) {
        self.model = model
        self.client = client ?? GroqClient(credentialStore: credentialStore)
    }

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionProviderResult {
        let text = try await client.transcribe(
            audioURL: request.audioURL,
            model: model,
            language: request.language,
            prompt: prompt(for: request.dictionaryTerms),
            translateToEnglish: request.translationRequested
        )
        return TranscriptionProviderResult(text: text, rawText: text)
    }

    private func prompt(for terms: [String]) -> String? {
        let cleanTerms = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(30)
        guard !cleanTerms.isEmpty else { return nil }
        return "Use estas grafias quando fizer sentido: \(cleanTerms.joined(separator: ", "))."
    }
}

struct GroqLLMProvider: LLMProvider {
    private let model: String
    private let client: GroqClient

    init(
        model: String,
        client: GroqClient? = nil,
        credentialStore: GroqCredentialStoring = GroqCredentialStore()
    ) {
        self.model = model
        self.client = client ?? GroqClient(credentialStore: credentialStore)
    }

    func process(_ request: LLMProcessingRequest) async throws -> String {
        try await client.chat(
            model: model,
            messages: PromptBuilder.messages(for: request),
            temperature: 0
        )
    }
}

enum PromptBuilder {
    static func messages(for request: LLMProcessingRequest) -> [ChatMessage] {
        [
            ChatMessage(
                role: "system",
                content: systemPrompt(for: request)
            ),
            ChatMessage(
                role: "user",
                content: request.text
            )
        ]
    }

    private static func systemPrompt(for request: LLMProcessingRequest) -> String {
        let toneInstruction: String
        switch request.formattingOptions.tone {
        case .colloquial:
            toneInstruction = "Use tom natural e coloquial."
        case .natural:
            toneInstruction = "Use tom natural, claro e direto."
        case .formal:
            toneInstruction = "Use tom formal, claro e profissional."
        }

        let paragraphInstruction = request.formattingOptions.addParagraphs
            ? "Quebre em parágrafos quando melhorar a leitura."
            : "Não crie parágrafos extras."
        let finalPeriodInstruction = request.formattingOptions.removeFinalPeriod
            ? "Remova o ponto final se a resposta tiver apenas uma frase."
            : "Mantenha pontuação normal."
        let dateInstruction = request.formattingOptions.formatDates
            ? "Normalize datas quando estiverem claramente ditadas."
            : "Não altere datas."
        let timeInstruction = request.formattingOptions.formatTimes
            ? "Normalize horários quando estiverem claramente ditados."
            : "Não altere horários."
        let listInstruction = request.formattingOptions.formatLists
            ? "Converta listas ditadas em linhas separadas quando ficar óbvio."
            : "Não transforme texto em lista."
        let translationInstruction = request.translationRequested
            ? "Traduza o texto para \(request.translationTargetLanguage)."
            : "Não traduza o idioma do texto."

        return """
        Você recebe uma transcrição de ditado. Corrija pontuação, capitalização e pequenos erros óbvios, sem inventar conteúdo.
        \(translationInstruction)
        \(toneInstruction)
        \(paragraphInstruction)
        \(finalPeriodInstruction)
        \(dateInstruction)
        \(timeInstruction)
        \(listInstruction)
        Responda apenas com o texto final, sem comentários.
        """
    }
}
