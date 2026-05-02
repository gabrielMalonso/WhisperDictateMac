import SwiftUI

struct PermissionsView: View {
    @ObservedObject private var manager = PermissionManager.shared

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary
                summaryBanner

                // Permission rows card
                SettingsComponents.card {
                    SettingsComponents.sectionHeader(String(localized: "Permissões"))

                    permissionRow(
                        icon: "mic.fill",
                        title: String(localized: "Microfone"),
                        description: String(localized: "Necessário para gravação de áudio"),
                        granted: manager.microphoneGranted,
                        action: { manager.requestMicrophone() }
                    )

                    SettingsComponents.divider()

                    permissionRow(
                        icon: "hand.raised.fill",
                        title: String(localized: "Acessibilidade"),
                        description: String(localized: "Necessário para colar texto no app ativo"),
                        granted: manager.accessibilityGranted,
                        action: { manager.openAccessibilitySettings() }
                    )

                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "Permissões"))
        .onAppear { manager.startPolling() }
        .onDisappear { manager.stopPolling() }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        let allGranted = manager.allPermissionsGranted
        let color: Color = allGranted ? .green : .orange
        let icon = allGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        let text = allGranted
            ? String(localized: "Todas as permissões concedidas")
            : AppText.pendingPermissions(manager.pendingCount)

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(text)
                .font(AppTypography.row.weight(.medium))
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Permission Row

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(granted ? .green : accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.row)
                Text(description)
                    .font(AppTypography.helper)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(String(localized: "Ativar")) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(accentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
