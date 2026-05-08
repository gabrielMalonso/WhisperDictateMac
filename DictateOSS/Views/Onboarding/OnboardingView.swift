import SwiftUI

// MARK: - OnboardingStep

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case groq
    case microphone
    case accessibility
    case hotkey
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared

    @State private var currentStep: OnboardingStep = .welcome

    private let slideTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Spacer()

            stepContent
                .frame(maxWidth: 420)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            navigationButtons
                .padding(.bottom, 32)
        }
        .frame(width: 600, height: 450)
        .onAppear { permissionManager.startPolling() }
        .onDisappear { permissionManager.stopPolling() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            progressDots

            Button(String(localized: "Pular")) { completeOnboarding(openAISettings: false) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            OnboardingWelcomeStep()
                .transition(slideTransition)
        case .groq:
            OnboardingGroqStep()
                .transition(slideTransition)
        case .microphone:
            OnboardingMicrophoneStep()
                .transition(slideTransition)
        case .accessibility:
            OnboardingAccessibilityStep()
                .transition(slideTransition)
        case .hotkey:
            OnboardingHotkeyStep()
                .transition(slideTransition)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep != .welcome {
                Button(String(localized: "Voltar")) {
                    withAnimation { goToPreviousStep() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(currentStep == OnboardingStep.allCases.last ? String(localized: "Concluir") : String(localized: "Continuar")) {
                if currentStep == OnboardingStep.allCases.last {
                    completeOnboarding(openAISettings: true)
                } else {
                    withAnimation { goToNextStep() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canContinue)
        }
    }

    // MARK: - Navigation Logic

    private var canContinue: Bool {
        switch currentStep {
        case .welcome, .groq, .hotkey:
            true
        case .microphone:
            permissionManager.microphoneGranted
        case .accessibility:
            permissionManager.accessibilityGranted
        }
    }

    private func goToNextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func goToPreviousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    private func completeOnboarding(openAISettings: Bool) {
        withAnimation(ContentView.rootTransitionAnimation) {
            UserDefaults.app.set(openAISettings, forKey: MacAppKeys.openAISettingsAfterOnboarding)
            UserDefaults.app.set(true, forKey: MacAppKeys.onboardingCompleted)
            permissionManager.stopPolling()
        }
    }
}

#Preview {
    OnboardingView()
}
