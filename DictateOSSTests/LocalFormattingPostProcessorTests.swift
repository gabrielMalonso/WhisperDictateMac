import XCTest
@testable import DictateOSS

final class LocalFormattingPostProcessorTests: XCTestCase {
    func testWrapTranscriptionEscapesAngleBrackets() {
        let result = LocalFormattingPostProcessor.wrapTranscription("use <tag>")

        XCTAssertEqual(result, "<transcription>\nuse &lt;tag&gt;\n</transcription>")
    }

    func testStripXmlTagsRemovesKnownPromptTags() {
        let result = LocalFormattingPostProcessor.stripXmlTags(
            #"<guardrail priority="critical">x</guardrail><task id="formatting">y</task>"#
        )

        XCTAssertEqual(result, "xy")
    }

    func testRemoveFinalPeriodsPerLinePreservesEllipsis() {
        let result = LocalFormattingPostProcessor.removeFinalPeriods("Primeira linha.\nSegunda linha...\nTerceira.")

        XCTAssertEqual(result, "Primeira linha\nSegunda linha...\nTerceira")
    }

    func testPostProcessStripsTagsAndRemovesFinalPeriodWhenEnabled() {
        let result = LocalFormattingPostProcessor.postProcessFormattedText(
            "<transcription>Oi tudo bem.</transcription>",
            options: .default
        )

        XCTAssertEqual(result, "Oi tudo bem")
    }
}
