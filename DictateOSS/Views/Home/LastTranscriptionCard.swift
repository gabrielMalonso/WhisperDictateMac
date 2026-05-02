import SwiftUI
import SwiftData

struct RecentTranscriptionsCard: View {
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse)
    private var allRecords: [TranscriptionRecord]

    private var records: [TranscriptionRecord] {
        Array(allRecords.prefix(3))
    }

    var body: some View {
        SettingsComponents.card {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "Transcrições Recentes").localizedUppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                if records.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            SettingsComponents.divider()
                        }
                        TranscriptionRowView(record: record)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.quaternary)

            Text(String(localized: "Sua primeira transcrição aparecerá aqui"))
                .font(AppTypography.row)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Transcription Row

private struct TranscriptionRowView: View {
    let record: TranscriptionRecord
    @State private var showCopiedFeedback = false
    @State private var now = Date()

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.text)
                    .font(.system(.body, design: .serif))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(record.compactMetadata(to: now))
                }
                .font(AppTypography.helper)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.text, forType: .string)
                withAnimation { showCopiedFeedback = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showCopiedFeedback = false }
                }
            } label: {
                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(AppTypography.helper)
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(showCopiedFeedback ? .green : accentColor)
                    .padding(6)
                    .background(accentColor.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onReceive(minuteTimer) { now = $0 }
    }
}
