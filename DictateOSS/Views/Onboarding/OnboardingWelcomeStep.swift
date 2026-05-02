import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(String(localized: "Bem-vindo ao Dictate"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "Transcreva sua voz em qualquer app do Mac"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    OnboardingWelcomeStep()
        .frame(width: 420)
        .padding()
}
