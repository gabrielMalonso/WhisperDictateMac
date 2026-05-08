import SwiftUI

struct OnboardingGroqStep: View {
    private let steps = [
        String(localized: "onboarding.groq.step.sign_in"),
        String(localized: "onboarding.groq.step.create_free_key"),
        String(localized: "onboarding.groq.step.paste_key")
    ]

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)

            Text(String(localized: "onboarding.groq.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "onboarding.groq.subtitle"))
                .font(AppTypography.row)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)

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
                Label(String(localized: "onboarding.groq.open_keys"), systemImage: "key")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Text(String(localized: "onboarding.groq.footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }
}

#Preview {
    OnboardingGroqStep()
        .frame(width: 420)
        .padding()
}
