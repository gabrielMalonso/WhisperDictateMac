import SwiftData
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Binding var activeSettingsModal: SettingsModal?

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsComponents.brandedHeader(
                    String(localized: "Ajustes").lowercased(with: AppUILanguage.current.locale)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)

                geralDoAppSection
                sistemaModalSection
                dadosSection

                Text(String(localized: "Versão \(appVersion)"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .detailCardStyle()
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    // MARK: - Geral Do App Section

    private var geralDoAppSection: some View {
        SettingsComponents.card {
            Button {
                withAnimation(SettingsModalLayout.animation) {
                    activeSettingsModal = .general
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Geral"))
                            .font(SettingsComponents.rowFont)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sistema Modal Section

    private var sistemaModalSection: some View {
        SettingsComponents.card {
            Button {
                withAnimation(SettingsModalLayout.animation) {
                    activeSettingsModal = .system
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.2")
                        .font(.body)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)

                    Text(String(localized: "Sistema"))
                        .font(SettingsComponents.rowFont)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Dados Section

    private var dadosSection: some View {
        SettingsComponents.card {
            NavigationLink(value: DetailRoute.statsDetail) {
                SettingsComponents.row(
                    icon: "chart.bar",
                    title: String(localized: "Estatísticas Detalhadas")
                ) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            SettingsComponents.divider()

            NavigationLink(value: DetailRoute.feedback) {
                SettingsComponents.row(
                    icon: "envelope",
                    title: String(localized: "Enviar Feedback")
                ) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView(activeSettingsModal: .constant(nil))
        .frame(width: 500, height: 700)
}
