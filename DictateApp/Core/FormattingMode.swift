import Foundation

enum TranscriptionDomain: String, Codable, CaseIterable, Identifiable {
    case general
    case tech
    case medical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: String(localized: "Geral")
        case .tech: String(localized: "TI / Dev")
        case .medical: String(localized: "Medicina")
        }
    }

    var icon: String {
        switch self {
        case .general: "globe"
        case .tech: "chevron.left.forwardslash.chevron.right"
        case .medical: "cross.case"
        }
    }

    var description: String {
        switch self {
        case .general: String(localized: "Transcricao padrao, sem contexto especializado")
        case .tech: String(localized: "Frameworks, linguagens, siglas de TI e DevOps")
        case .medical: String(localized: "Termos anatomicos, patologias, exames e laudos")
        }
    }
}

enum Tone: String, Codable, CaseIterable {
    case colloquial
    case natural
    case formal
}

struct FormattingOptions: Codable, Equatable {
    var tone: Tone = .natural
    var addParagraphs: Bool = true
    var removeFinalPeriod: Bool = true
    var formatDates: Bool = true
    var formatTimes: Bool = true
    var formatLists: Bool = true

    private enum CodingKeys: String, CodingKey {
        case tone
        case addParagraphs
        case removeFinalPeriod
        case formatDates
        case formatTimes
        case formatLists
    }

    init(
        tone: Tone = .natural,
        addParagraphs: Bool = true,
        removeFinalPeriod: Bool = true,
        formatDates: Bool = true,
        formatTimes: Bool = true,
        formatLists: Bool = true
    ) {
        self.tone = tone
        self.addParagraphs = addParagraphs
        self.removeFinalPeriod = removeFinalPeriod
        self.formatDates = formatDates
        self.formatTimes = formatTimes
        self.formatLists = formatLists
    }

    static let `default` = FormattingOptions()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tone = try container.decodeIfPresent(Tone.self, forKey: .tone) ?? .natural
        addParagraphs = try container.decodeIfPresent(Bool.self, forKey: .addParagraphs) ?? true
        removeFinalPeriod = try container.decodeIfPresent(Bool.self, forKey: .removeFinalPeriod) ?? true
        formatDates = try container.decodeIfPresent(Bool.self, forKey: .formatDates) ?? true
        formatTimes = try container.decodeIfPresent(Bool.self, forKey: .formatTimes) ?? true
        formatLists = try container.decodeIfPresent(Bool.self, forKey: .formatLists) ?? true
    }

    var activeToggleCount: Int {
        [addParagraphs, removeFinalPeriod, formatDates, formatTimes, formatLists].filter { $0 }.count
    }

    var displaySummary: String {
        let toneLabel: String
        switch tone {
        case .colloquial: toneLabel = String(localized: "Coloquial")
        case .natural: toneLabel = String(localized: "Natural")
        case .formal: toneLabel = String(localized: "Formal")
        }

        if activeToggleCount > 0 {
            return AppText.adjustmentsSummary(toneLabel: toneLabel, activeToggleCount: activeToggleCount)
        }
        return toneLabel
    }

    // MARK: - Persistence

    func save(to defaults: UserDefaultsProviding = UserDefaults.app) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: MacAppKeys.formattingOptions)
        }
    }

    static func load(from defaults: UserDefaultsProviding = UserDefaults.app) -> FormattingOptions {
        if let data = defaults.data(forKey: MacAppKeys.formattingOptions),
           let options = try? JSONDecoder().decode(FormattingOptions.self, from: data) {
            return options
        }
        return .default
    }
}
