import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "Pipeline")

enum TranscriptionFallbackReason: Equatable {
    case offline
    case unauthenticated
    case networkFailure
}

struct TranscriptionRouteResult {
    let text: String
    let rawText: String?
    let usedLocalFallback: Bool
    let fallbackReason: TranscriptionFallbackReason?

    static func localOnly(text: String) -> TranscriptionRouteResult {
        TranscriptionRouteResult(
            text: text,
            rawText: nil,
            usedLocalFallback: false,
            fallbackReason: nil
        )
    }
}

enum TranscriptionPipelineError: LocalizedError, Equatable {
    case cancelled
    case emptyResult
    case localTranscriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return String(localized: "Operação cancelada.")
        case .emptyResult:
            return String(localized: "A transcrição ficou vazia.")
        case .localTranscriptionFailed(let message):
            return message
        }
    }
}

private actor TranscriptionCancellationRegistry {
    private var cancelledClientIDs = Set<UUID>()

    func requestCancellation(for clientId: UUID) {
        cancelledClientIDs.insert(clientId)
    }

    func isCancellationRequested(for clientId: UUID) -> Bool {
        cancelledClientIDs.contains(clientId)
    }

    func clearCancellation(for clientId: UUID) {
        cancelledClientIDs.remove(clientId)
    }
}

enum TranscriptionPipeline {
    private static let cancellationRegistry = TranscriptionCancellationRegistry()

    struct TranscriptionResult {
        let text: String
        let wordCount: Int
        let clientId: UUID
        let persistedLanguage: String
        let usedLocalFallback: Bool
        let fallbackReason: TranscriptionFallbackReason?
    }

    @MainActor
    static func transcribe(
        audioURL: URL,
        audioDuration: Double = 0,
        clientId: UUID = UUID(),
        persistResult: Bool = true,
        translationRequested: Bool = false,
        defaults: UserDefaultsProviding = UserDefaults.app,
        modelContext: ModelContext = ModelContext(AppModelContainer.container)
    ) async -> Result<TranscriptionResult, TranscriptionPipelineError> {
        let selectedLanguage = defaults.string(forKey: MacAppKeys.transcriptionLanguage) ?? DeviceLanguageMapper.deviceDefault
        let persistedLanguage = selectedLanguage
        let dictionaryTerms = loadDictionaryTerms(
            language: selectedLanguage,
            modelContext: modelContext,
            defaults: defaults
        )

        logger.info(
            """
            Pipeline start: mode=mlx, \
            selectedLanguage=\(selectedLanguage, privacy: .public), \
            dictionaryTermsCount=\(dictionaryTerms.count)
            """
        )

        let localResult = await LocalTranscriptionService.transcribe(
            audioURL: audioURL,
            language: selectedLanguage == "auto" ? nil : selectedLanguage
        )

        if await cancelIfRequested(clientId: clientId) {
            return .failure(.cancelled)
        }

        let route: TranscriptionRouteResult
        switch localResult {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(.emptyResult)
            }
            route = .localOnly(text: trimmed)
        case .failure(let error):
            return .failure(.localTranscriptionFailed(error.localizedDescription))
        }

        let finalText = postProcess(
            route: route,
            dictionaryTerms: dictionaryTerms,
            language: selectedLanguage,
            defaults: defaults,
            modelContext: modelContext
        )

        if await cancelIfRequested(clientId: clientId) {
            return .failure(.cancelled)
        }

        logger.info(
            """
            Post-process completed: \
            chars=\(finalText.count), \
            words=\(finalText.split(separator: " ").count)
            """
        )

        if persistResult {
            persistRecord(
                text: finalText,
                audioDuration: audioDuration,
                language: persistedLanguage,
                clientId: clientId,
                modelContext: modelContext
            )
        }

        return .success(makeResult(
            text: finalText,
            clientId: clientId,
            persistedLanguage: persistedLanguage,
            usedLocalFallback: route.usedLocalFallback,
            fallbackReason: route.fallbackReason
        ))
    }

    static func requestCancellation(for clientId: UUID?) async {
        guard let clientId else { return }
        await cancellationRegistry.requestCancellation(for: clientId)
    }
}

private extension TranscriptionPipeline {
    static func makeResult(
        text: String,
        clientId: UUID,
        persistedLanguage: String,
        usedLocalFallback: Bool,
        fallbackReason: TranscriptionFallbackReason?
    ) -> TranscriptionResult {
        TranscriptionResult(
            text: text,
            wordCount: text.split(separator: " ").count,
            clientId: clientId,
            persistedLanguage: persistedLanguage,
            usedLocalFallback: usedLocalFallback,
            fallbackReason: fallbackReason
        )
    }

    static func cancelIfRequested(clientId: UUID) async -> Bool {
        let cancelled = await cancellationRegistry.isCancellationRequested(for: clientId)
        if cancelled {
            await cancellationRegistry.clearCancellation(for: clientId)
        }
        return cancelled
    }

    static func postProcess(
        route: TranscriptionRouteResult,
        dictionaryTerms: [String],
        language: String,
        defaults: UserDefaultsProviding,
        modelContext: ModelContext
    ) -> String {
        let afterDictionary = DictionaryMatcher.apply(terms: dictionaryTerms, to: route.text, language: language)
        if afterDictionary != route.text {
            logger.info(
                """
                Dictionary adjusted transcription: \
                beforeChars=\(route.text.count), \
                afterChars=\(afterDictionary.count)
                """
            )
        } else {
            logger.info("Dictionary made no changes")
        }
        return applyReplacementRules(
            transcriptionText: afterDictionary,
            rawText: route.rawText,
            defaults: defaults,
            modelContext: modelContext
        )
    }

    static func loadDictionaryTerms(
        language: String,
        modelContext: ModelContext,
        defaults: UserDefaultsProviding = UserDefaults.app
    ) -> [String] {
        let enabled = defaults.object(forKey: MacAppKeys.dictionaryEnabled) as? Bool ?? true
        guard enabled else { return [] }
        let entries = (try? modelContext.fetch(FetchDescriptor<DictionaryEntry>())) ?? []
        if language == "auto" {
            return entries.map { $0.term }
        }
        return entries
            .filter { $0.language == language }
            .map { $0.term }
    }

    static func applyReplacementRules(
        transcriptionText: String,
        rawText: String?,
        defaults: UserDefaultsProviding,
        modelContext: ModelContext
    ) -> String {
        let rulesEnabled = defaults.object(forKey: MacAppKeys.replacementRulesEnabled) as? Bool ?? true
        guard rulesEnabled else {
            logger.info("Replacement rules disabled")
            return transcriptionText
        }
        guard let rules = try? modelContext.fetch(
            FetchDescriptor<ReplacementRule>(predicate: #Predicate { $0.isEnabled })
        ), !rules.isEmpty else {
            logger.info("Replacement rules enabled but no active rules found")
            return transcriptionText
        }

        let useCountsBefore = Dictionary(rules.map { ($0.id, $0.useCount) }, uniquingKeysWith: { _, last in last })

        if let rawText {
            let rawResult = ReplacementEngine.apply(rules: rules, to: rawText, context: modelContext)
            if rawResult.replacementCount > 0 {
                logger.info("Replacement rules matched raw text: count=\(rawResult.replacementCount)")
                saveModifiedRules(rules: rules, useCountsBefore: useCountsBefore, modelContext: modelContext)
                return rawResult.text
            }
        }

        let processedResult = ReplacementEngine.apply(rules: rules, to: transcriptionText, context: modelContext)
        if processedResult.replacementCount > 0 {
            logger.info("Replacement rules matched transcription: count=\(processedResult.replacementCount)")
            saveModifiedRules(rules: rules, useCountsBefore: useCountsBefore, modelContext: modelContext)
        }
        return processedResult.text
    }

    static func saveModifiedRules(
        rules: [ReplacementRule],
        useCountsBefore: [UUID: Int],
        modelContext: ModelContext
    ) {
        let modifiedRules = rules.filter { $0.useCount != useCountsBefore[$0.id] }
        guard !modifiedRules.isEmpty else { return }
        do {
            try modelContext.save()
            logger.info("Saved \(modifiedRules.count) updated replacement rules locally")
        } catch {
            logger.error("Failed to save replacement-rule counters: \(error.localizedDescription)")
        }
    }

}

extension TranscriptionPipeline {
    static func persistRecord(
        text: String,
        audioDuration: Double,
        language: String,
        clientId: UUID,
        modelContext: ModelContext
    ) {
        let existingDescriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { $0.id == clientId }
        )
        if let existing = try? modelContext.fetch(existingDescriptor).first {
            existing.text = text
            existing.wordCount = text.split(separator: " ").count
            existing.durationSeconds = max(existing.durationSeconds, audioDuration)
            existing.language = language
        } else {
            let record = TranscriptionRecord(
                text: text,
                durationSeconds: audioDuration,
                language: language
            )
            record.id = clientId
            modelContext.insert(record)
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("Pipeline: failed to save transcription: \(error.localizedDescription)")
        }
    }
}
