import Foundation

/// Single source of truth for mapping short language codes (e.g. "pt", "en")
/// to full locale identifiers used by the speech stack.
enum SpeechLocaleMapper {

    private static let languageToLocaleID: [String: String] = [
        "pt": "pt-BR",
        "en": "en-US",
        "es": "es-ES",
        "fr": "fr-FR"
    ]

    /// Returns the `Locale` for a given language code.
    ///
    /// - `nil` or `"auto"` -> `Locale.current`
    /// - Known code (e.g. `"pt"`) -> mapped locale (e.g. `pt-BR`)
    /// - Unknown string -> used as-is as a locale identifier
    static func locale(for language: String?) -> Locale {
        guard let language, language != "auto" else {
            return Locale.current
        }
        if let localeID = languageToLocaleID[language] {
            return Locale(identifier: localeID)
        }
        return Locale(identifier: language)
    }
}
