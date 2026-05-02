import SwiftUI

struct StatsQuickCard: View {
    @AppStorage(MacAppKeys.localWeekDictations, store: .app)
    private var weekCount: Int = 0

    @AppStorage(MacAppKeys.localWeekWords, store: .app)
    private var weekWords: Int = 0

    @AppStorage(MacAppKeys.localCurrentStreak, store: .app)
    private var streak: Int = 0

    static var currentWeekRange: String {
        let interval = currentWeekInterval()
        let formatter = DateFormatter()
        formatter.locale = AppUILanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        let today = Date.now

        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: min(interval.end, today)))"
    }

    static func currentWeekInterval(now: Date = .now, calendar baseCalendar: Calendar = .current) -> DateInterval {
        var calendar = baseCalendar
        calendar.firstWeekday = 2

        let start = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? now
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? now
        return DateInterval(start: start, end: end)
    }

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        SettingsComponents.card {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    statCell(value: weekCount, label: String(localized: "ditados"))
                    divider
                    statCell(value: weekWords, label: String(localized: "palavras"))
                    if streak > 0 {
                        divider
                        statCell(
                            value: streak,
                            label: streak == 1 ? String(localized: "dia") : String(localized: "dias"),
                            accent: true
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 36)
    }

    private func statCell(value: Int, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if accent {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
                Text("\(value)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(accent ? accentColor : .primary)
            }
            Text(label.localizedUppercased())
                .font(.caption.weight(.medium))
                .tracking(1)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
