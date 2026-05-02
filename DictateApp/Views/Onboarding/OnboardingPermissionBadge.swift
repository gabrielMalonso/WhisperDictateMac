import SwiftUI

struct OnboardingPermissionBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)

            Text(granted ? String(localized: "Permissão concedida") : String(localized: "Aguardando permissão..."))
                .font(AppTypography.helper)
                .foregroundStyle(granted ? .primary : .secondary)
        }
        .padding(.top, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingPermissionBadge(granted: false)
        OnboardingPermissionBadge(granted: true)
    }
    .padding()
}
