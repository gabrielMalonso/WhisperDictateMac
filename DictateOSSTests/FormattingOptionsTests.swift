import XCTest
@testable import DictateOSS

final class FormattingOptionsTests: XCTestCase {
    func testDefaultHasAllFormattingBooleansEnabled() {
        let options = FormattingOptions.default

        XCTAssertEqual(options.tone, .natural)
        XCTAssertTrue(options.addParagraphs)
        XCTAssertTrue(options.removeFinalPeriod)
        XCTAssertTrue(options.formatDates)
        XCTAssertTrue(options.formatTimes)
        XCTAssertTrue(options.formatLists)
    }

    func testDecoderMissingFieldsDefaultsToEnabled() throws {
        let data = #"{"tone":"formal"}"#.data(using: .utf8)!

        let options = try JSONDecoder().decode(FormattingOptions.self, from: data)

        XCTAssertEqual(options.tone, .formal)
        XCTAssertTrue(options.addParagraphs)
        XCTAssertTrue(options.removeFinalPeriod)
        XCTAssertTrue(options.formatDates)
        XCTAssertTrue(options.formatTimes)
        XCTAssertTrue(options.formatLists)
    }

    func testSaveAndLoadRoundTrip() {
        let defaults = TestDefaults()
        let original = FormattingOptions(
            tone: .colloquial,
            addParagraphs: false,
            removeFinalPeriod: true,
            formatDates: true,
            formatTimes: false,
            formatLists: false
        )

        original.save(to: defaults)

        XCTAssertEqual(FormattingOptions.load(from: defaults), original)
    }
}
