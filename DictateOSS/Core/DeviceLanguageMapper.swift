import Foundation

enum DeviceLanguageMapper {
    private static let supportedLanguages: Set<String> = ["pt", "en", "es", "fr"]

    static var deviceDefault: String {
        guard let code = Locale.current.language.languageCode?.identifier else {
            return "auto"
        }
        return supportedLanguages.contains(code) ? code : "auto"
    }
}
