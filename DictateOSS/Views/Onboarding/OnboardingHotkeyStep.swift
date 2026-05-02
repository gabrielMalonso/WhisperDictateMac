import SwiftUI

struct OnboardingHotkeyStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(String(localized: "Seu atalho global"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "Pressione este atalho em qualquer app para iniciar/parar a ditação."))
                .font(AppTypography.row)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SettingsComponents.card {
                HotkeySettingView(style: .compactRow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    OnboardingHotkeyStep()
        .frame(width: 420)
        .padding()
}
