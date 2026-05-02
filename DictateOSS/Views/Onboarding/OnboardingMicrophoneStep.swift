import SwiftUI

struct OnboardingMicrophoneStep: View {
    @ObservedObject private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(String(localized: "Precisamos acessar seu microfone"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "Para transcrever sua voz, o Dictate precisa de permissão para usar o microfone."))
                .font(AppTypography.row)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                permissionManager.requestMicrophone()
            } label: {
                Label(String(localized: "Permitir Microfone"), systemImage: "mic")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(permissionManager.microphoneGranted)
            .padding(.top, 8)

            OnboardingPermissionBadge(granted: permissionManager.microphoneGranted)
        }
    }
}

#Preview {
    OnboardingMicrophoneStep()
        .frame(width: 420)
        .padding()
}
