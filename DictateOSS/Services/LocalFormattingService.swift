import Foundation
import os

private let formattingLogger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "LocalFormatting")

protocol LocalTextFormatting {
    func format(
        rawText: String,
        options: FormattingOptions,
        language: String,
        defaults: UserDefaultsProviding
    ) async -> String
}

struct LocalFormattingService: LocalTextFormatting {
    private let llmClient: LocalLLMClient
    private let promptBuilder: LocalFormattingPromptBuilder

    init(
        llmClient: LocalLLMClient = OllamaLocalLLMClient(),
        promptBuilder: LocalFormattingPromptBuilder = LocalFormattingPromptBuilder()
    ) {
        self.llmClient = llmClient
        self.promptBuilder = promptBuilder
    }

    func format(
        rawText: String,
        options: FormattingOptions,
        language: String,
        defaults: UserDefaultsProviding = UserDefaults.app
    ) async -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let configuration = LocalLLMConfiguration.load(from: defaults)
        guard configuration.isEnabled else {
            formattingLogger.info("Local formatting skipped: disabled")
            return trimmed
        }
        guard trimmed.count >= configuration.minCharsToFormat else {
            formattingLogger.info("Local formatting skipped: below min chars")
            return trimmed
        }
        guard configuration.isLocalEndpoint else {
            formattingLogger.warning("Local formatting skipped: endpoint is not local")
            return trimmed
        }

        do {
            try Task.checkCancellation()
            let systemPrompt = promptBuilder.buildSystemPrompt(options: options, language: language)
            let response = try await llmClient.complete(
                systemPrompt: systemPrompt,
                userText: trimmed,
                configuration: configuration
            )
            try Task.checkCancellation()
            let formatted = LocalFormattingPostProcessor.postProcessFormattedText(response, options: options)
            guard !formatted.isEmpty else {
                formattingLogger.warning("Local formatting returned empty text; falling back to raw")
                return trimmed
            }
            formattingLogger.info("Local formatting completed: before=\(trimmed.count), after=\(formatted.count)")
            return formatted
        } catch is CancellationError {
            formattingLogger.info("Local formatting cancelled")
            return trimmed
        } catch {
            formattingLogger.warning("Local formatting failed: \(error.localizedDescription)")
            return trimmed
        }
    }
}

protocol LocalAudioTranscribing {
    func transcribe(audioURL: URL, language: String?) async -> Result<String, LocalTranscriptionService.LocalTranscriptionError>
}

struct MLXLocalAudioTranscriber: LocalAudioTranscribing {
    func transcribe(audioURL: URL, language: String?) async -> Result<String, LocalTranscriptionService.LocalTranscriptionError> {
        await LocalTranscriptionService.transcribe(audioURL: audioURL, language: language)
    }
}

struct TranscriptionPipelineDependencies {
    let transcriber: any LocalAudioTranscribing
    let formatter: any LocalTextFormatting

    init(
        transcriber: any LocalAudioTranscribing = MLXLocalAudioTranscriber(),
        formatter: any LocalTextFormatting = LocalFormattingService()
    ) {
        self.transcriber = transcriber
        self.formatter = formatter
    }
}
