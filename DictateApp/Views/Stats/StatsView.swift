import SwiftUI

struct StatsView: View {
    @AppStorage(MacAppKeys.syncTotalDictations, store: .app)
    private var totalDictations: Int = 0

    @AppStorage(MacAppKeys.syncTotalWords, store: .app)
    private var totalWords: Int = 0

    @AppStorage(MacAppKeys.syncTotalDurationSeconds, store: .app)
    private var totalDurationSeconds: Double = 0

    @AppStorage(MacAppKeys.weeklyUsed, store: .app)
    private var weeklyUsed: Int = 0

    @AppStorage(MacAppKeys.weeklyLimit, store: .app)
    private var weeklyLimit: Int = 0

    @AppStorage(MacAppKeys.weeklyResetsAt, store: .app)
    private var weeklyResetsAtTimestamp: Double = 0

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsComponents.brandedHeader(
                    String(localized: "Estatísticas").lowercased(with: AppUILanguage.current.locale)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)

                totalsCard
                weeklyUsageCard
                editionCard
            }
            .padding(24)
            .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Totals Card

    private var totalsCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Totais"))

            HStack(spacing: 16) {
                statCard(
                    title: String(localized: "Ditados"),
                    value: "\(totalDictations)",
                    icon: "mic.fill"
                )
                statCard(
                    title: String(localized: "Palavras"),
                    value: "\(totalWords)",
                    icon: "text.word.spacing"
                )
                statCard(
                    title: String(localized: "Duração"),
                    value: formattedDuration,
                    icon: "clock.fill"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Weekly Usage Card

    private var weeklyUsageCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Uso Semanal"))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppText.transcriptionsThisWeek(used: weeklyUsed, limit: effectiveWeeklyLimit))
                        .font(AppTypography.row)
                    Spacer()
                    Text(weeklyPercentageText)
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: weeklyProgress)
                    .tint(weeklyProgressColor)

                if weeklyResetsAtTimestamp > 0 {
                    Text(String(localized: "Reseta em: \(formattedResetDate)"))
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Edition Card

    private var editionCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Edição"))

            HStack {
                Text(String(localized: "Open Source"))
                    .font(AppTypography.row)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(accentColor)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Reusable Components

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accentColor)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    // MARK: - Computed Properties

    private var formattedDuration: String {
        let totalSeconds = Int(totalDurationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var effectiveWeeklyLimit: Int {
        weeklyLimit > 0 ? weeklyLimit : AppConfig.proWeeklyLimit
    }

    private var weeklyProgress: Double {
        guard effectiveWeeklyLimit > 0 else { return 0 }
        return min(Double(weeklyUsed) / Double(effectiveWeeklyLimit), 1.0)
    }

    private var weeklyPercentageText: String {
        weeklyProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    private var weeklyProgressColor: Color {
        if weeklyProgress >= 0.9 {
            return .red
        } else if weeklyProgress >= 0.7 {
            return .orange
        } else {
            return accentColor
        }
    }

    private var formattedResetDate: String {
        let date = Date(timeIntervalSince1970: weeklyResetsAtTimestamp)
        let formatter = DateFormatter()
        formatter.locale = AppUILanguage.current.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    StatsView()
        .frame(width: 500, height: 500)
}
