import SwiftData
import XCTest
@testable import DictateOSS

final class AIProviderSelectionTests: XCTestCase {
    func testDefaultModeUsesGroqAsFastPath() {
        let defaults = makeDefaults()

        let selection = AIProviderSelection.current(from: defaults)

        XCTAssertEqual(selection.mode, .groq)
        XCTAssertEqual(selection.transcriptionProvider, .groq)
        XCTAssertEqual(selection.llmProvider, .groq)
        XCTAssertTrue(selection.fallbackToLocal)
    }

    func testLocalModeUsesLocalTranscriptionAndNoLLM() {
        let defaults = makeDefaults()
        defaults.set(AIMode.local.rawValue, forKey: MacAppKeys.aiMode)
        defaults.set(TranscriptionProviderKind.groq.rawValue, forKey: MacAppKeys.transcriptionProvider)
        defaults.set(LLMProviderKind.groq.rawValue, forKey: MacAppKeys.llmProvider)

        let selection = AIProviderSelection.current(from: defaults)

        XCTAssertEqual(selection.mode, .local)
        XCTAssertEqual(selection.transcriptionProvider, .local)
        XCTAssertEqual(selection.llmProvider, .none)
        XCTAssertFalse(selection.fallbackToLocal)
    }

    func testGroqModeUsesGroqForBothStagesAndKeepsFallbackEnabledByDefault() {
        let defaults = makeDefaults()
        defaults.set(AIMode.groq.rawValue, forKey: MacAppKeys.aiMode)

        let selection = AIProviderSelection.current(from: defaults)

        XCTAssertEqual(selection.mode, .groq)
        XCTAssertEqual(selection.transcriptionProvider, .groq)
        XCTAssertEqual(selection.llmProvider, .groq)
        XCTAssertTrue(selection.fallbackToLocal)
    }

    func testCustomModeUsesExplicitProviders() {
        let defaults = makeDefaults()
        defaults.set(AIMode.custom.rawValue, forKey: MacAppKeys.aiMode)
        defaults.set(TranscriptionProviderKind.groq.rawValue, forKey: MacAppKeys.transcriptionProvider)
        defaults.set(LLMProviderKind.local.rawValue, forKey: MacAppKeys.llmProvider)
        defaults.set(false, forKey: MacAppKeys.groqFallbackToLocal)

        let selection = AIProviderSelection.current(from: defaults)

        XCTAssertEqual(selection.mode, .custom)
        XCTAssertEqual(selection.transcriptionProvider, .groq)
        XCTAssertEqual(selection.llmProvider, .local)
        XCTAssertFalse(selection.fallbackToLocal)
    }

    func testCancellationAfterTranscriptionSkipsLLMProcessing() async throws {
        let defaults = makeDefaults()
        let clientId = UUID()
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancel-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        try Data().write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let modelContext = try makeInMemoryModelContext()
        let llmCall = LLMCallRecorder()
        await TranscriptionPipeline.requestCancellation(for: clientId)

        let result = await TranscriptionPipeline.transcribe(
            audioURL: audioURL,
            clientId: clientId,
            persistResult: false,
            defaults: defaults,
            modelContext: modelContext,
            routeTranscriber: { _, _, _ in
                .remote(text: "texto transcrito", rawText: "texto transcrito")
            },
            llmProcessor: { route, _, _, _, _ in
                llmCall.markCalled()
                return route
            }
        )

        guard case .failure(.cancelled) = result else {
            return XCTFail("Expected cancellation after transcription, got \(result)")
        }
        XCTAssertFalse(llmCall.called)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AIProviderSelectionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeInMemoryModelContext() throws -> ModelContext {
        let config = ModelConfiguration(
            schema: AppModelContainer.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: config)
        return ModelContext(container)
    }
}

private final class LLMCallRecorder {
    private(set) var called = false

    func markCalled() {
        called = true
    }
}
