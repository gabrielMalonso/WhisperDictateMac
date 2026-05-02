import SwiftUI

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    @State private var showCopiedFeedback = false

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header Card

                SettingsComponents.card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(record.createdAt, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 20, weight: .semibold, design: .serif))

                        HStack(spacing: 6) {
                            Text(record.createdAt, style: .time)
                            Text("\u{00B7}")
                            Text(AppText.wordCount(record.wordCount))
                            Text("\u{00B7}")
                            Text(languageFullName(for: record.language))
                        }
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)

                        Divider()
                            .overlay(Color.primary.opacity(0.04))

                        HStack(spacing: 12) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.text, forType: .string)
                                withAnimation { showCopiedFeedback = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopiedFeedback = false }
                                }
                            } label: {
                                Label(
                                    showCopiedFeedback ? String(localized: "Copiado!") : String(localized: "Copiar"),
                                    systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                                )
                                .font(AppTypography.helper.weight(.semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(accentColor.opacity(0.08))
                                .foregroundStyle(accentColor)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            ShareLink(
                                item: record.text,
                                preview: SharePreview(String(localized: "Transcrição de Voz"))
                            ) {
                                Label(String(localized: "Compartilhar"), systemImage: "square.and.arrow.up")
                                    .font(AppTypography.helper.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(accentColor.opacity(0.08))
                                    .foregroundStyle(accentColor)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }

                // MARK: - Transcription Card

                SettingsComponents.card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Transcrição"))
                            .font(AppTypography.helper.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(.tertiary)

                        Text(record.text)
                            .font(.system(size: 18, design: .serif))
                            .textSelection(.enabled)
                    }
                    .padding(20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "Transcrição"))
    }

    // MARK: - Helpers

    private func languageFullName(for code: String) -> String {
        switch code {
        case "pt": return String(localized: "Português")
        case "en": return String(localized: "English")
        case "es": return String(localized: "Español")
        case "fr": return String(localized: "Français")
        case "auto": return String(localized: "Auto-detectado")
        default: return code
        }
    }
}

#Preview {
    HistoryDetailView(
        record: TranscriptionRecord(
            text: "Esta e uma transcricao de exemplo para visualizar o layout do detalhe do historico.",
            wordCount: 14,
            durationSeconds: 32,
            language: "pt"
        )
    )
    .modelContainer(for: TranscriptionRecord.self, inMemory: true)
    .frame(width: 500, height: 400)
}
