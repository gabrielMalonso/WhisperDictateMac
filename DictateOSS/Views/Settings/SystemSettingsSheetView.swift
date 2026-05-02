import SwiftUI

struct SystemSettingsSheetView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue
    let modalSize: CGSize
    let openPermissions: () -> Void
    let resetOnboarding: () -> Void

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                systemCard
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(width: modalSize.width, height: modalSize.height)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 10)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Sistema"))
                .font(.system(size: 28, weight: .bold, design: .serif))

            Spacer()
        }
    }

    private var systemCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Aparência"))

            HStack(spacing: 0) {
                ForEach(AccentColorOption.allCases, id: \.rawValue) { option in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            accentColorRaw = option.rawValue
                        }
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if accentColorRaw == option.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(accentColorRaw == option.rawValue ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            SettingsComponents.divider()

            Button(action: openPermissions) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.body)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Text(String(localized: "Permissões"))
                        .font(SettingsComponents.rowFont)
                    Spacer()
                    if permissionManager.pendingCount == 0 {
                        Text(String(localized: "OK"))
                            .font(SettingsComponents.helperFont)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    } else {
                        Text(AppText.pendingPermissions(permissionManager.pendingCount))
                            .font(SettingsComponents.helperFont)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            SettingsComponents.divider()

            Link(destination: AppConfig.termsOfUseURL) {
                SettingsComponents.row(icon: "doc.text", title: String(localized: "Termos de Uso"))
            }
            .buttonStyle(.plain)

            SettingsComponents.divider()

            Link(destination: AppConfig.privacyPolicyURL) {
                SettingsComponents.row(icon: "hand.raised", title: String(localized: "Política de Privacidade"))
            }
            .buttonStyle(.plain)

            SettingsComponents.divider()

            Button(role: .destructive, action: resetOnboarding) {
                SettingsComponents.row(
                    icon: "arrow.counterclockwise",
                    title: String(localized: "Refazer onboarding")
                ) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SystemSettingsSheetView(
        modalSize: CGSize(width: SettingsModalLayout.maxWidth, height: SettingsModalLayout.maxHeight),
        openPermissions: {},
        resetOnboarding: {}
    )
}
