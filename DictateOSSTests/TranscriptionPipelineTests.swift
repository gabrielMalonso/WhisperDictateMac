import SwiftData
import XCTest
@testable import DictateOSS

@MainActor
final class TranscriptionPipelineTests: XCTestCase {
    func testPipelineFormatsBeforeReplacementRulesAndPersistsResult() async throws {
        let context = try makeTestModelContext()
        let defaults = TestDefaults()
        defaults.set("pt", forKey: MacAppKeys.transcriptionLanguage)
        defaults.set(true, forKey: MacAppKeys.replacementRulesEnabled)
        defaults.set(true, forKey: MacAppKeys.dictionaryEnabled)

        let rule = ReplacementRule(originalText: "vc", replacementText: "voce")
        context.insert(rule)
        try context.save()

        let audioURL = makeTempAudioURL()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let dependencies = TranscriptionPipelineDependencies(
            transcriber: StubTranscriber(text: "raw vc sem formato"),
            formatter: StubFormatter(text: "Texto formatado com vc.")
        )

        let result = await TranscriptionPipeline.transcribe(
            audioURL: audioURL,
            clientId: UUID(),
            defaults: defaults,
            modelContext: context,
            dependencies: dependencies
        )

        guard case .success(let pipelineResult) = result else {
            return XCTFail("Expected success")
        }

        XCTAssertEqual(pipelineResult.text, "Texto formatado com voce.")
        let records = try context.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(records.first?.text, "Texto formatado com voce.")
    }

    func testPipelineUsesRawWhenFormatterFallsBack() async throws {
        let context = try makeTestModelContext()
        let defaults = TestDefaults()
        defaults.set("pt", forKey: MacAppKeys.transcriptionLanguage)
        let audioURL = makeTempAudioURL()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let dependencies = TranscriptionPipelineDependencies(
            transcriber: StubTranscriber(text: "texto cru"),
            formatter: StubFormatter(text: "texto cru")
        )

        let result = await TranscriptionPipeline.transcribe(
            audioURL: audioURL,
            defaults: defaults,
            modelContext: context,
            dependencies: dependencies
        )

        guard case .success(let pipelineResult) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(pipelineResult.text, "texto cru")
    }
}

private struct StubTranscriber: LocalAudioTranscribing {
    let text: String

    func transcribe(audioURL: URL, language: String?) async -> Result<String, LocalTranscriptionService.LocalTranscriptionError> {
        .success(text)
    }
}

private struct StubFormatter: LocalTextFormatting {
    let text: String

    func format(
        rawText: String,
        options: FormattingOptions,
        language: String,
        defaults: UserDefaultsProviding
    ) async -> String {
        text
    }
}
