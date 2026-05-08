import SwiftUI

struct OnboardingGroqStep: View {
    private let steps = [
        String(localized: "Acesse a Groq e crie uma conta ou faça login."),
        String(localized: "Abra API Keys e crie uma chave gratuita."),
        String(localized: "Copie a chave e cole no modal de IA do Dictate.")
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text(String(localized: "Modo rápido com Groq"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "O Dictate usa Groq como caminho rápido. No Free Tier, a chave é gratuita e generosa para começar."))
                .font(AppTypography.row)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.accentColor))

                        Text(step)
                            .font(AppTypography.row)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 2)

            Link(destination: AppConfig.groqAPIKeysURL) {
                Label(String(localized: "Abrir chaves da Groq"), systemImage: "key")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Text(String(localized: "Ao concluir, abriremos Dictate > Modo de IA para você colar a chave. No Free Tier, você usa até os limites gratuitos."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    OnboardingGroqStep()
        .frame(width: 420)
        .padding()
}
