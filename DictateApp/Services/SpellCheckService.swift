import AppKit

enum SpellCheckService {

    private static let localeMapping: [String: [String]] = [
        "pt": ["pt_BR", "pt"],
        "en": ["en_US", "en", "en_GB"],
        "es": ["es", "es_ES", "es_MX"],
        "fr": ["fr", "fr_FR"]
    ]

    static func isKnownWord(_ word: String, language: String) -> Bool {
        guard language != "auto" else {
            let available = Set(NSSpellChecker.shared.availableLanguages)
            let checker = NSSpellChecker.shared
            for candidates in localeMapping.values {
                guard let localeId = candidates.first(where: { available.contains($0) }) else { continue }
                var wordCount: Int = 0
                let misspelledRange = checker.checkSpelling(
                    of: word,
                    startingAt: 0,
                    language: localeId,
                    wrap: false,
                    inSpellDocumentWithTag: 0,
                    wordCount: &wordCount
                )
                if misspelledRange.location == NSNotFound {
                    return true
                }
            }
            return false
        }
        guard let localeId = resolveLocale(for: language) else { return false }

        let checker = NSSpellChecker.shared
        var wordCount: Int = 0
        let misspelledRange = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: localeId,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: &wordCount
        )
        return misspelledRange.location == NSNotFound
    }

    private static func resolveLocale(for language: String) -> String? {
        guard let candidates = localeMapping[language] else { return nil }
        let available = Set(NSSpellChecker.shared.availableLanguages)
        return candidates.first { available.contains($0) }
    }
}
