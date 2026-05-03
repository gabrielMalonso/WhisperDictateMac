import XCTest
@testable import DictateOSS

final class LocalFormattingPromptBuilderTests: XCTestCase {
    private let builder = LocalFormattingPromptBuilder()

    func testColloquialPromptIncludesColloquialToneAndOutputContract() {
        let prompt = builder.buildSystemPrompt(
            options: FormattingOptions(tone: .colloquial, addParagraphs: false, formatDates: false, formatTimes: false, formatLists: false),
            language: "pt"
        )

        XCTAssertTrue(prompt.contains("Preserve gírias"))
        XCTAssertTrue(prompt.contains("Retorne SOMENTE o texto formatado"))
        XCTAssertTrue(prompt.contains("<output-contract"))
    }

    func testNaturalPromptIncludesFillerRemoval() {
        let prompt = builder.buildSystemPrompt(
            options: FormattingOptions(tone: .natural, addParagraphs: false, formatDates: false, formatTimes: false, formatLists: false),
            language: "pt"
        )

        XCTAssertTrue(prompt.contains("Remova vícios de linguagem oral"))
        XCTAssertTrue(prompt.contains("tom informal mas escrito"))
    }

    func testFormalPromptIncludesWrittenTextInstruction() {
        let prompt = builder.buildSystemPrompt(
            options: FormattingOptions(tone: .formal, addParagraphs: false, formatDates: false, formatTimes: false, formatLists: false),
            language: "pt"
        )

        XCTAssertTrue(prompt.contains("Converta esta transcrição de fala em texto escrito"))
        XCTAssertTrue(prompt.contains("Remova completamente vícios"))
    }

    func testEnabledTogglesAddConditionalTasks() {
        let prompt = builder.buildSystemPrompt(
            options: FormattingOptions(tone: .natural, addParagraphs: true, formatDates: true, formatTimes: true, formatLists: true),
            language: "pt"
        )

        XCTAssertTrue(prompt.contains("Divida o texto em parágrafos curtos"))
        XCTAssertTrue(prompt.contains("Reconheça datas faladas"))
        XCTAssertTrue(prompt.contains("Reconheça horários falados"))
        XCTAssertTrue(prompt.contains("enumerando itens ou fazendo uma lista"))
    }

    func testPromptPreservesLanguageAndNeverAnswersQuestions() {
        let prompt = builder.buildSystemPrompt(options: .default, language: "en")

        XCTAssertTrue(prompt.contains("Preserve o idioma da transcrição"))
        XCTAssertTrue(prompt.contains("Não traduza"))
        XCTAssertTrue(prompt.contains("NUNCA responda perguntas"))
    }
}
