import SwiftUI
import AppKit

// MARK: - Accent Color Option

enum AccentColorOption: String, CaseIterable, Codable {
    case `default`
    case orange
    case yellow
    case green
    case pink
    case purple

    var color: Color {
        switch self {
        case .default: return Color(nsColor: .systemBlue)
        case .orange:  return Color(nsColor: .systemOrange)
        case .yellow:  return Color(nsColor: .systemYellow)
        case .green:   return Color(nsColor: .systemGreen)
        case .pink:    return Color(nsColor: .systemPink)
        case .purple:  return Color(nsColor: .systemPurple)
        }
    }

    var displayName: String {
        switch self {
        case .default: return String(localized: "Padrão")
        case .orange:  return String(localized: "Laranja")
        case .yellow:  return String(localized: "Amarelo")
        case .green:   return String(localized: "Verde")
        case .pink:    return String(localized: "Rosa")
        case .purple:  return String(localized: "Roxo")
        }
    }

    static func current() -> AccentColorOption {
        let raw = UserDefaults.app.string(forKey: MacAppKeys.keyboardAccentColor) ?? "default"
        return AccentColorOption(rawValue: raw) ?? .default
    }
}
