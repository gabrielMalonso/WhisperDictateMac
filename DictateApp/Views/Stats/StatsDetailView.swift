import SwiftUI
import Charts

struct StatsDetailView: View {
    private struct WeeklyChartPoint: Identifiable {
        let id: String
        let weekStart: Date
        let dictations: Int
    }

    private struct WeeklyChartEntry: Decodable {
        let weekStart: String
        let dictations: Int
    }

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @AppStorage(MacAppKeys.syncTotalDictations, store: .app)
    private var syncTotalDictations: Int = 0

    @AppStorage(MacAppKeys.syncTotalWords, store: .app)
    private var syncTotalWords: Int = 0

    @AppStorage(MacAppKeys.syncCurrentStreak, store: .app)
    private var currentStreak: Int = 0

    @AppStorage(MacAppKeys.syncLongestStreak, store: .app)
    private var longestStreak: Int = 0

    @AppStorage(MacAppKeys.syncThisMonthDictations, store: .app)
    private var thisMonthDictations: Int = 0

    @AppStorage(MacAppKeys.syncLast7DaysDictations, store: .app)
    private var last7DaysDictations: Int = 0

    @AppStorage(MacAppKeys.syncBestDayDate, store: .app)
    private var bestDayDate: String = ""

    @AppStorage(MacAppKeys.syncBestDayDictations, store: .app)
    private var bestDayDictations: Int = 0

    @AppStorage(MacAppKeys.syncWeeklyChart, store: .app)
    private var weeklyChartData: Data = Data()

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let rowFont = SettingsComponents.rowFont
    private let helperFont = SettingsComponents.helperFont

    private var totalCount: Int { syncTotalDictations }
    private var totalWords: Int { syncTotalWords }
    private var averageWords: Double {
        guard totalCount > 0 else { return 0 }
        return Double(totalWords) / Double(totalCount)
    }

    private var weeklyChartEntries: [WeeklyChartEntry] {
        guard !weeklyChartData.isEmpty,
              let entries = try? JSONDecoder().decode([WeeklyChartEntry].self, from: weeklyChartData)
        else { return [] }
        return entries
    }

    private var weeklyChartPoints: [WeeklyChartPoint] {
        weeklyChartEntries.compactMap { entry in
            guard let weekStart = weekStartDate(from: entry.weekStart) else { return nil }
            return WeeklyChartPoint(
                id: entry.weekStart,
                weekStart: weekStart,
                dictations: entry.dictations
            )
        }
    }

    private var formattedBestDay: String {
        let parts = bestDayDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return bestDayDate
        }
        let language = AppUILanguage.current
        let calendar = language.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return bestDayDate
        }
        return date.formatted(.dateTime.locale(language.locale).day().month(.wide))
    }

    var body: some View {
        Group {
            if syncTotalDictations == 0 {
                ContentUnavailableView(
                    String(localized: "Sem dados"),
                    systemImage: "chart.bar",
                    description: Text(String(localized: "Suas estatísticas aparecerão aqui após usar o teclado de voz."))
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Métricas Header
                        SettingsComponents.card {
                            HStack(spacing: 0) {
                                statCell(value: "\(totalCount)", label: String(localized: "ditados"))
                                statDivider
                                statCell(value: formatNumber(totalWords), label: String(localized: "palavras"))
                                statDivider
                                statCell(value: AppText.decimal(averageWords), label: String(localized: "pal/dit"))
                            }
                            .padding(.vertical, 16)
                        }

                        // MARK: - Chart
                        SettingsComponents.card {
                            sectionHeader(String(localized: "Últimas 8 semanas"))

                            if weeklyChartPoints.isEmpty {
                                Text("—")
                                    .font(helperFont)
                                    .foregroundStyle(.tertiary)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Chart(weeklyChartPoints) { entry in
                                    BarMark(
                                        x: .value("Semana", entry.weekStart, unit: .weekOfYear),
                                        y: .value("Ditados", entry.dictations)
                                    )
                                    .foregroundStyle(accentColor.gradient)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        if let date = value.as(Date.self) {
                                            AxisValueLabel(
                                                date.formatted(
                                                    .dateTime
                                                        .locale(AppUILanguage.current.locale)
                                                        .day()
                                                        .month(.abbreviated)
                                                )
                                            )
                                        }
                                    }
                                }
                                .frame(height: 150)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                            }
                        }

                        // MARK: - Detalhes
                        SettingsComponents.card {
                            sectionHeader(String(localized: "Detalhes"))

                            detailRow(label: String(localized: "Este mês"), value: AppText.dictations(thisMonthDictations))
                            Divider().padding(.leading, 20)
                            detailRow(label: String(localized: "Últimos 7 dias"), value: AppText.dictations(last7DaysDictations))
                            if !bestDayDate.isEmpty {
                                Divider().padding(.leading, 20)
                                detailRow(
                                    label: String(localized: "Melhor dia"),
                                    value: AppText.bestDaySummary(day: formattedBestDay, count: bestDayDictations)
                                )
                            }
                            Divider().padding(.leading, 20)
                            detailRow(label: String(localized: "Sequência atual"), value: AppText.dayCount(currentStreak))
                            Divider().padding(.leading, 20)
                            detailRow(label: String(localized: "Maior sequência"), value: AppText.dayCount(longestStreak))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "Estatísticas"))
    }

    // MARK: - Components

    /// Local sectionHeader with .bottom(8) instead of the standard .bottom(4)
    private func sectionHeader(_ title: String) -> some View {
        Text(title.localizedUppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 28)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.bold))
            Text(label.localizedUppercased())
                .font(helperFont.weight(.medium))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(rowFont)
            Spacer()
            Text(value)
                .font(rowFont)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func formatNumber(_ number: Int) -> String {
        AppText.compactNumber(number)
    }

    private func weekStartDate(from rawValue: String) -> Date? {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
