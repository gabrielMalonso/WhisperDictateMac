import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsComponents.brandedHeader(String(localized: "início"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(String(localized: "Esta semana").localizedUppercased())
                        Text("·")
                        Text(StatsQuickCard.currentWeekRange.localizedUppercased())
                    }
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)

                    NavigationLink(value: DetailRoute.statsDetail) {
                        StatsQuickCard()
                    }
                    .buttonStyle(.plain)
                }

                RecentTranscriptionsCard()
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .detailCardStyle()
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
    }
}
