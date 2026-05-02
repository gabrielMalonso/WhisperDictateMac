import Foundation

enum AppUILanguage {
    case english
    case portuguese

    static var current: AppUILanguage {
        let preferredLanguage = Bundle.main.preferredLocalizations.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("en") ? .english : .portuguese
    }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .portuguese:
            return Locale(identifier: "pt-BR")
        }
    }

    var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        return calendar
    }
}

enum AppText {
    static func compactNumber(_ value: Int, language: AppUILanguage = .current) -> String {
        value.formatted(
            .number
                .locale(language.locale)
                .notation(.compactName)
        )
    }

    static func decimal(_ value: Double, fractionDigits: Int = 1, language: AppUILanguage = .current) -> String {
        value.formatted(
            .number
                .locale(language.locale)
                .precision(.fractionLength(fractionDigits))
        )
    }

    static func wordCount(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "word", pluralEn: "words", singularPt: "palavra", pluralPt: "palavras", language: language)
    }

    static func dayCount(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "day", pluralEn: "days", singularPt: "dia", pluralPt: "dias", language: language)
    }

    static func shortMinuteCount(_ count: Int, language: AppUILanguage = .current) -> String {
        let formattedCount = format(count, language: language)
        switch language {
        case .english:
            return "\(formattedCount) min"
        case .portuguese:
            return "\(formattedCount) min"
        }
    }

    static func shortHourCount(_ count: Int, language: AppUILanguage = .current) -> String {
        let formattedCount = format(count, language: language)
        switch language {
        case .english:
            return "\(formattedCount) hr"
        case .portuguese:
            return "\(formattedCount) h"
        }
    }

    static func shortWeekCount(_ count: Int, language: AppUILanguage = .current) -> String {
        let formattedCount = format(count, language: language)
        switch language {
        case .english:
            return "\(formattedCount) wk"
        case .portuguese:
            return "\(formattedCount) sem"
        }
    }

    static func dictations(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "dictation", pluralEn: "dictations", singularPt: "ditado", pluralPt: "ditados", language: language)
    }

    static func rulesCount(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "rule", pluralEn: "rules", singularPt: "regra", pluralPt: "regras", language: language)
    }

    static func termsCount(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "term", pluralEn: "terms", singularPt: "termo", pluralPt: "termos", language: language)
    }

    static func pendingItems(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(count, singularEn: "pending", pluralEn: "pending", singularPt: "pendente", pluralPt: "pendentes", language: language)
    }

    static func pendingPermissions(_ count: Int, language: AppUILanguage = .current) -> String {
        quantified(
            count,
            singularEn: "pending permission",
            pluralEn: "pending permissions",
            singularPt: "permissão pendente",
            pluralPt: "permissões pendentes",
            language: language
        )
    }

    static func transcriptionsThisWeek(used: Int, limit: Int, language: AppUILanguage = .current) -> String {
        let formattedUsed = format(used, language: language)
        let formattedLimit = format(limit, language: language)

        switch language {
        case .english:
            return "\(formattedUsed) / \(formattedLimit) transcriptions this week"
        case .portuguese:
            return "\(formattedUsed) / \(formattedLimit) transcrições esta semana"
        }
    }

    static func transcriptionCountThisWeek(_ count: Int, language: AppUILanguage = .current) -> String {
        let formattedCount = format(count, language: language)

        switch language {
        case .english:
            let noun = count == 1 ? "transcription" : "transcriptions"
            return "\(formattedCount) \(noun) this week"
        case .portuguese:
            let noun = count == 1 ? "transcrição" : "transcrições"
            return "\(formattedCount) \(noun) esta semana"
        }
    }

    static func weeklyUsage(used: Int, limit: Int, language: AppUILanguage = .current) -> String {
        let formattedUsed = format(used, language: language)
        let formattedLimit = format(limit, language: language)

        switch language {
        case .english:
            return "\(formattedUsed) of \(formattedLimit) this week"
        case .portuguese:
            return "\(formattedUsed) de \(formattedLimit) esta semana"
        }
    }

    static func quotaUsage(used: Int, limit: Int, language: AppUILanguage = .current) -> String {
        let formattedUsed = format(used, language: language)
        let formattedLimit = format(limit, language: language)

        switch language {
        case .english:
            return "\(formattedUsed) of \(formattedLimit)"
        case .portuguese:
            return "\(formattedUsed) de \(formattedLimit)"
        }
    }

    static func hourlyUsageLimit(_ limit: Int, language: AppUILanguage = .current) -> String {
        let formattedLimit = format(limit, language: language)

        switch language {
        case .english:
            return "\(formattedLimit) transcriptions per hour"
        case .portuguese:
            return "\(formattedLimit) transcrições por hora"
        }
    }

    static func hourlyUsage(used: Int, limit: Int, language: AppUILanguage = .current) -> String {
        let formattedUsed = format(used, language: language)
        let formattedLimit = format(limit, language: language)

        switch language {
        case .english:
            return "\(formattedUsed) of \(formattedLimit) this hour"
        case .portuguese:
            return "\(formattedUsed) de \(formattedLimit) por hora"
        }
    }

    static func hourlyUsageLimitTitle(language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "Hourly limit"
        case .portuguese:
            return "Limite por hora"
        }
    }

    static func adjustmentsSummary(
        toneLabel: String,
        activeToggleCount: Int,
        language: AppUILanguage = .current
    ) -> String {
        guard activeToggleCount > 0 else { return toneLabel }

        let formattedCount = format(activeToggleCount, language: language)

        switch language {
        case .english:
            let noun = activeToggleCount == 1 ? "adjustment" : "adjustments"
            return "\(toneLabel) + \(formattedCount) \(noun)"
        case .portuguese:
            let noun = activeToggleCount == 1 ? "ajuste" : "ajustes"
            return "\(toneLabel) + \(formattedCount) \(noun)"
        }
    }

    static func bestDaySummary(day: String, count: Int, language: AppUILanguage = .current) -> String {
        "\(day) (\(format(count, language: language)))"
    }

    static func recordingStatus(timestamp: String, language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "Recording (\(timestamp))"
        case .portuguese:
            return "Gravando (\(timestamp))"
        }
    }

    static func rateLimit(seconds: Int, language: AppUILanguage = .current) -> String {
        let formattedSeconds = format(seconds, language: language)

        switch language {
        case .english:
            return "Usage limit reached. Try again in \(formattedSeconds) seconds."
        case .portuguese:
            return "Limite de uso atingido. Tente novamente em \(formattedSeconds) segundos."
        }
    }

    static func permissionRequired(_ permission: String, language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "\(permission) access is required for Dictate to work. Grant permission in System Settings."
        case .portuguese:
            return "O acesso de \(permission) é necessário para o Dictate funcionar. Conceda a permissão em Ajustes do Sistema."
        }
    }

    static func imageImportFailure(language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "Couldn't load the selected images."
        case .portuguese:
            return "Não foi possível carregar as imagens selecionadas."
        }
    }

    static func feedbackURLFailure(language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "Couldn't open the feedback form."
        case .portuguese:
            return "Não foi possível abrir o formulário de feedback."
        }
    }

    static func justNow(language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "now"
        case .portuguese:
            return "agora"
        }
    }

    static func hotkeyKeyName(for keyCode: UInt16, language: AppUILanguage = .current) -> String? {
        switch keyCode {
        case 36:
            switch language {
            case .english: return "Return"
            case .portuguese: return "Enter"
            }
        case 48:
            switch language {
            case .english: return "Tab"
            case .portuguese: return "Tab"
            }
        case 49:
            switch language {
            case .english: return "Space"
            case .portuguese: return "Espaço"
            }
        case 51:
            switch language {
            case .english: return "Delete"
            case .portuguese: return "Apagar"
            }
        case 53:
            switch language {
            case .english: return "Esc"
            case .portuguese: return "Esc"
            }
        default:
            return nil
        }
    }

    static func unknownHotkeyKeyName(for keyCode: UInt16, language: AppUILanguage = .current) -> String {
        switch language {
        case .english:
            return "Key\(keyCode)"
        case .portuguese:
            return "Tecla\(keyCode)"
        }
    }

    private static func quantified(
        _ count: Int,
        singularEn: String,
        pluralEn: String,
        singularPt: String,
        pluralPt: String,
        language: AppUILanguage
    ) -> String {
        let formattedCount = format(count, language: language)

        switch language {
        case .english:
            return "\(formattedCount) \(count == 1 ? singularEn : pluralEn)"
        case .portuguese:
            return "\(formattedCount) \(count == 1 ? singularPt : pluralPt)"
        }
    }

    private static func format(_ value: Int, language: AppUILanguage) -> String {
        value.formatted(.number.locale(language.locale))
    }

}

extension String {
    func localizedUppercased(language: AppUILanguage = .current) -> String {
        uppercased(with: language.locale)
    }
}
