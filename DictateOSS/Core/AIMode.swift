import Foundation

enum AIMode: String, CaseIterable, Identifiable {
    case local
    case groq
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local: String(localized: "Local")
        case .groq: String(localized: "Groq")
        case .custom: String(localized: "Personalizado")
        }
    }

    var detail: String {
        switch self {
        case .local:
            String(localized: "Transcreve no Mac e mantém áudio e texto fora de APIs externas.")
        case .groq:
            String(localized: "Mais rápido, mas envia áudio e texto para a Groq usando sua chave.")
        case .custom:
            String(localized: "Escolha transcrição e LLM separadamente.")
        }
    }

    static func current(from defaults: UserDefaultsProviding = UserDefaults.app) -> AIMode {
        AIMode(rawValue: defaults.string(forKey: MacAppKeys.aiMode) ?? "") ?? .local
    }
}

enum TranscriptionProviderKind: String, CaseIterable, Identifiable {
    case local
    case groq

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local: String(localized: "MLX Whisper local")
        case .groq: String(localized: "Groq Whisper")
        }
    }
}

enum LLMProviderKind: String, CaseIterable, Identifiable {
    case none
    case local
    case groq

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "Desligado")
        case .local: String(localized: "Ollama local")
        case .groq: String(localized: "Groq LLM")
        }
    }
}

struct AIProviderSelection: Equatable {
    let mode: AIMode
    let transcriptionProvider: TranscriptionProviderKind
    let llmProvider: LLMProviderKind
    let fallbackToLocal: Bool

    static func current(from defaults: UserDefaultsProviding = UserDefaults.app) -> AIProviderSelection {
        let mode = AIMode.current(from: defaults)
        let fallback = defaults.object(forKey: MacAppKeys.groqFallbackToLocal) as? Bool ?? true

        switch mode {
        case .local:
            return AIProviderSelection(
                mode: mode,
                transcriptionProvider: .local,
                llmProvider: .none,
                fallbackToLocal: false
            )
        case .groq:
            return AIProviderSelection(
                mode: mode,
                transcriptionProvider: .groq,
                llmProvider: .groq,
                fallbackToLocal: fallback
            )
        case .custom:
            return AIProviderSelection(
                mode: mode,
                transcriptionProvider: TranscriptionProviderKind(
                    rawValue: defaults.string(forKey: MacAppKeys.transcriptionProvider) ?? ""
                ) ?? .local,
                llmProvider: LLMProviderKind(
                    rawValue: defaults.string(forKey: MacAppKeys.llmProvider) ?? ""
                ) ?? .none,
                fallbackToLocal: fallback
            )
        }
    }
}
