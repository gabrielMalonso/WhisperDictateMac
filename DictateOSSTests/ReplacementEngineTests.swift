import SwiftData
import XCTest
@testable import DictateOSS

final class ReplacementEngineTests: XCTestCase {
    func testSingleMatchReplacesAndIncrementsUseCount() throws {
        let context = try makeTestModelContext()
        let rule = ReplacementRule(originalText: "vc", replacementText: "voce")
        context.insert(rule)
        try context.save()

        let result = ReplacementEngine.apply(rules: [rule], to: "vc e vc", context: context)

        XCTAssertEqual(result.text, "voce e voce")
        XCTAssertEqual(result.replacementCount, 2)
        XCTAssertEqual(rule.useCount, 2)
    }

    func testDisabledRuleIsSkipped() throws {
        let context = try makeTestModelContext()
        let rule = ReplacementRule(originalText: "vc", replacementText: "voce")
        rule.isEnabled = false
        context.insert(rule)
        try context.save()

        let result = ReplacementEngine.apply(rules: [rule], to: "vc sabe", context: context)

        XCTAssertEqual(result.text, "vc sabe")
        XCTAssertEqual(result.replacementCount, 0)
    }

    func testNormalizedPunctuationMatch() throws {
        let context = try makeTestModelContext()
        let rule = ReplacementRule(originalText: "comando: conta cirurgia", replacementText: "Texto longo")
        context.insert(rule)
        try context.save()

        let result = ReplacementEngine.apply(rules: [rule], to: "disse comando, conta cirurgia agora", context: context)

        XCTAssertEqual(result.text, "disse Texto longo agora")
        XCTAssertEqual(result.replacementCount, 1)
    }

    func testReplacementTextWithDollarSignIsLiteral() throws {
        let context = try makeTestModelContext()
        let rule = ReplacementRule(originalText: "cmd", replacementText: "R$ 100,00")
        context.insert(rule)
        try context.save()

        let result = ReplacementEngine.apply(rules: [rule], to: "cmd aqui", context: context)

        XCTAssertEqual(result.text, "R$ 100,00 aqui")
    }
}
