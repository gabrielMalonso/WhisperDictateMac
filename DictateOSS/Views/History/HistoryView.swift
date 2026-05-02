import SwiftData
import SwiftUI

struct HistoryDetailRoute: Hashable {
    let recordID: UUID
}

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse)
    private var records: [TranscriptionRecord]

    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""

    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return records
        }
        let query = searchText.lowercased()
        return records.filter { $0.text.lowercased().contains(query) }
    }

    // MARK: - Day Grouping

    private struct DayGroup: Identifiable {
        let date: Date
        let title: String
        let items: [TranscriptionRecord]
        var id: Date { date }
    }

    private var groupedByDay: [DayGroup] {
        let calendar = AppUILanguage.current.calendar
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.createdAt)
        }
        return grouped.map { (date, records) in
            DayGroup(date: date, title: formatDayTitle(date, calendar: calendar), items: records)
        }
        .sorted { $0.date > $1.date }
    }

    private func formatDayTitle(_ date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "Hoje")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Ontem")
        } else {
            return date.formatted(.dateTime.locale(AppUILanguage.current.locale).day().month(.wide).year())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsComponents.brandedHeader(
                    String(localized: "Histórico").lowercased(with: AppUILanguage.current.locale)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 12)

                // Search field inline
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "Buscar transcrições"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(groupedByDay) { group in
                            Text(group.title.localizedUppercased())
                                .font(.caption.weight(.semibold))
                                .tracking(1)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, group.date == groupedByDay.first?.date ? 4 : 12)
                                .padding(.bottom, 2)

                            ForEach(group.items) { record in
                                NavigationLink(value: HistoryDetailRoute(recordID: record.id)) {
                                    recordRow(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .detailCardStyle()
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationDestination(for: HistoryDetailRoute.self) { route in
            if let record = records.first(where: { $0.id == route.recordID }) {
                HistoryDetailView(record: record)
            } else {
                ContentUnavailableView(
                    String(localized: "Registro não encontrado"),
                    systemImage: "doc.questionmark"
                )
            }
        }
    }

    // MARK: - Record Row

    private func recordRow(_ record: TranscriptionRecord) -> some View {
        HistoryRowView(record: record)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .contextMenu {
                Button(String(localized: "Copiar Texto")) {
                    copyToClipboard(record.text)
                }
                Divider()
                Button(String(localized: "Apagar"), role: .destructive) {
                    deleteRecord(record)
                }
            }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(String(
                localized: "Nenhuma transcrição ainda.\nPressione \(hotkeyManager.formattedHotkey(for: .dictation)) para começar."
            ))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(AppTypography.row)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }
}

// MARK: - Row View

private struct HistoryRowView: View {
    let record: TranscriptionRecord

    @State private var now = Date()

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .lineLimit(2)
                .font(.system(.body, design: .serif))

            HStack(spacing: 6) {
                Text(record.createdAt.relativeShort(to: now))

                Text(String(localized: "·"))

                Text(record.compactMetadataDetails)

                Spacer(minLength: 4)

                Text(record.language.uppercased())
                    .font(AppTypography.helper.weight(.medium))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .font(AppTypography.helper)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .onReceive(minuteTimer) { now = $0 }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: TranscriptionRecord.self, inMemory: true)
        .frame(width: 700, height: 500)
}
