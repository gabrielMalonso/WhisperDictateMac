import XCTest
@testable import DictateOSS

final class DictionaryMatcherTests: XCTestCase {
    func testEmptyDictionaryReturnsOriginalText() {
        XCTAssertEqual(DictionaryMatcher.apply(terms: [], to: "texto qualquer"), "texto qualquer")
    }

    func testExactMatchPreservesDictionaryCasing() {
        XCTAssertEqual(DictionaryMatcher.apply(terms: ["CID"], to: "resultado do cid"), "resultado do CID")
    }

    func testLongTermFuzzyMatch() {
        XCTAssertEqual(
            DictionaryMatcher.apply(terms: ["Pamella"], to: "a pamela ligou", language: "pt"),
            "a Pamella ligou"
        )
    }

    func testMultiwordFuzzyMatch() {
        XCTAssertEqual(
            DictionaryMatcher.apply(terms: ["NOSSA Assessoria"], to: "ligou da nosa asesoria pedindo"),
            "ligou da NOSSA Assessoria pedindo"
        )
    }

    func testLevenshteinDistance() {
        XCTAssertEqual(DictionaryMatcher.levenshteinDistance("pamela", "pamella"), 1)
        XCTAssertEqual(DictionaryMatcher.levenshteinDistance("abc", ""), 3)
    }
}
