import SwiftUI

struct OnboardingAccessibilityStep: View {
    @ObservedObject private var permissionManager = PermissionManager.shared

    // swiftlint:disable:next line_length
    private let explanation = String(localized: "Para inserir o texto transcrito e capturar o atalho global, o Dictate precisa de permissão de Acessibilidade.")

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(String(localized: "Permissão de Acessibilidade"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(explanation)
                .font(AppTypography.row)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                permissionManager.openAccessibilitySettings()
            } label: {
                Label(String(localized: "Abrir Configurações"), systemImage: "gear")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(permissionManager.accessibilityGranted)
            .padding(.top, 8)

            OnboardingPermissionBadge(granted: permissionManager.accessibilityGranted)
        }
    }
}

#Preview {
    OnboardingAccessibilityStep()
        .frame(width: 420)
        .padding()
}
