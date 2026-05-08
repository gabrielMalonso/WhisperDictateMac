import XCTest
@testable import DictateOSS

final class AIProviderSelectionTests: XCTestCase {
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

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AIProviderSelectionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
