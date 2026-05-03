import XCTest
@testable import DictateOSS

final class LocalFormattingServiceTests: XCTestCase {
    func testDisabledFormattingReturnsRawText() async {
        let defaults = TestDefaults()
        defaults.set(false, forKey: MacAppKeys.localFormattingLLMEnabled)
        let llm = StubLLMClient(result: "Formatado")
        let service = LocalFormattingService(llmClient: llm)

        let result = await service.format(rawText: "  texto cru  ", options: .default, language: "pt", defaults: defaults)

        XCTAssertEqual(result, "texto cru")
        XCTAssertEqual(llm.completeCallCount, 0)
    }

    func testBelowThresholdSkipsLLM() async {
        let defaults = TestDefaults()
        defaults.set(100, forKey: MacAppKeys.localFormattingMinChars)
        let llm = StubLLMClient(result: "Formatado")
        let service = LocalFormattingService(llmClient: llm)

        let result = await service.format(rawText: "texto curto", options: .default, language: "pt", defaults: defaults)

        XCTAssertEqual(result, "texto curto")
        XCTAssertEqual(llm.completeCallCount, 0)
    }

    func testLLMResultIsPostProcessed() async {
        let defaults = TestDefaults()
        defaults.set(0, forKey: MacAppKeys.localFormattingMinChars)
        let llm = StubLLMClient(result: "<transcription>Texto formatado.</transcription>")
        let service = LocalFormattingService(llmClient: llm)

        let result = await service.format(rawText: "texto cru", options: .default, language: "pt", defaults: defaults)

        XCTAssertEqual(result, "Texto formatado")
        XCTAssertEqual(llm.completeCallCount, 1)
    }

    func testEmptyLLMResultFallsBackToRaw() async {
        let defaults = TestDefaults()
        defaults.set(0, forKey: MacAppKeys.localFormattingMinChars)
        let llm = StubLLMClient(result: "   ")
        let service = LocalFormattingService(llmClient: llm)

        let result = await service.format(rawText: "texto cru", options: .default, language: "pt", defaults: defaults)

        XCTAssertEqual(result, "texto cru")
    }

    func testLLMErrorFallsBackToRaw() async {
        let defaults = TestDefaults()
        defaults.set(0, forKey: MacAppKeys.localFormattingMinChars)
        let llm = StubLLMClient(error: OllamaLocalLLMError.emptyResponse)
        let service = LocalFormattingService(llmClient: llm)

        let result = await service.format(rawText: "texto cru", options: .default, language: "pt", defaults: defaults)

        XCTAssertEqual(result, "texto cru")
    }
}

private final class StubLLMClient: LocalLLMClient {
    let result: String?
    let error: Error?
    private(set) var completeCallCount = 0

    init(result: String? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func complete(
        systemPrompt: String,
        userText: String,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        completeCallCount += 1
        if let error { throw error }
        return result ?? ""
    }

    func installedModels(configuration: LocalLLMConfiguration) async throws -> [String] {
        []
    }
}
