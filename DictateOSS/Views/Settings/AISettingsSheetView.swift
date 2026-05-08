import SwiftUI

struct AISettingsSheetView: View {
    @AppStorage(MacAppKeys.aiMode, store: .app)
    private var aiModeRaw: String = AIMode.groq.rawValue

    @AppStorage(MacAppKeys.transcriptionProvider, store: .app)
    private var transcriptionProviderRaw: String = TranscriptionProviderKind.local.rawValue

    @AppStorage(MacAppKeys.llmProvider, store: .app)
    private var llmProviderRaw: String = LLMProviderKind.none.rawValue

    @AppStorage(MacAppKeys.groqWhisperModel, store: .app)
    private var groqWhisperModel: String = AppConfig.defaultGroqWhisperModel

    @AppStorage(MacAppKeys.groqLLMModel, store: .app)
    private var groqLLMModel: String = AppConfig.defaultGroqLLMModel

    @AppStorage(MacAppKeys.localLLMModel, store: .app)
    private var localLLMModel: String = AppConfig.defaultLocalLLMModel

    @AppStorage(MacAppKeys.groqFallbackToLocal, store: .app)
    private var groqFallbackToLocal: Bool = true

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var groqAPIKeyInput = ""
    @State private var hasGroqAPIKey = false
    @State private var groqStatusMessage: String?
    @State private var groqStatusIsError = false
    @State private var isTestingGroq = false

    let modalSize: CGSize

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private var currentAIMode: AIMode {
        AIMode(rawValue: aiModeRaw) ?? .groq
    }

    private var selectedTranscriptionProvider: TranscriptionProviderKind {
        TranscriptionProviderKind(rawValue: transcriptionProviderRaw) ?? .local
    }

    private var selectedLLMProvider: LLMProviderKind {
        LLMProviderKind(rawValue: llmProviderRaw) ?? .none
    }

    private var usesGroq: Bool {
        currentAIMode == .groq ||
            (currentAIMode == .custom && (selectedTranscriptionProvider == .groq || selectedLLMProvider == .groq))
    }

    private var usesLocalLLM: Bool {
        currentAIMode == .custom && selectedLLMProvider == .local
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                modeCard
                groqAccountCard
                if currentAIMode == .custom {
                    advancedCard
                }
                if usesGroq || usesLocalLLM {
                    modelsCard
                }
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
        .task {
            refreshGroqKeyState()
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Configurar IA"))
                .font(.system(size: 28, weight: .bold, design: .serif))
            Spacer()
        }
    }

    private var modeCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Uso"))

            VStack(spacing: 0) {
                modeButton(.groq, title: String(localized: "Rápido"), icon: "bolt.horizontal")
                SettingsComponents.divider()
                modeButton(.local, title: String(localized: "Privado"), icon: "lock.shield")
                SettingsComponents.divider()
                modeButton(.custom, title: String(localized: "Avançado"), icon: "slider.horizontal.3")
            }
        }
    }

    private func modeButton(_ mode: AIMode, title: String, icon: String) -> some View {
        Button {
            aiModeRaw = mode.rawValue
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: currentAIMode == mode ? "largecircle.fill.circle" : "circle")
                    .font(.body)
                    .foregroundStyle(currentAIMode == mode ? accentColor : .secondary)
                    .frame(width: 24)
                    .padding(.top, 2)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(accentColor)
                    .frame(width: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SettingsComponents.rowFont)
                    Text(mode.detail)
                        .font(SettingsComponents.helperFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var groqAccountCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Conta Groq"))

            SettingsComponents.rowWithDescription(
                icon: hasGroqAPIKey ? "key.fill" : "key",
                title: String(localized: "Chave da Groq"),
                description: hasGroqAPIKey
                    ? String(localized: "Chave salva no Keychain.")
                    : String(localized: "A chave fica salva neste Mac, no Keychain.")
            ) {
                SecureField(String(localized: "gsk_..."), text: $groqAPIKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
            }

            SettingsComponents.divider()

            HStack(spacing: 10) {
                Button(String(localized: "Salvar")) {
                    saveGroqAPIKey()
                }
                .disabled(groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(String(localized: "Testar")) {
                    testGroqConnection()
                }
                .disabled(!hasGroqAPIKey || isTestingGroq)

                Button(String(localized: "Apagar")) {
                    deleteGroqAPIKey()
                }
                .disabled(!hasGroqAPIKey)

                if isTestingGroq {
                    ProgressView()
                        .controlSize(.small)
                }

                if let groqStatusMessage {
                    Text(groqStatusMessage)
                        .font(SettingsComponents.helperFont)
                        .foregroundStyle(groqStatusIsError ? .red : .secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var advancedCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Avançado"))

            SettingsComponents.rowWithDescription(
                icon: "waveform",
                title: String(localized: "Transcrição"),
                description: String(localized: "Escolha quem transforma áudio em texto.")
            ) {
                Picker("", selection: $transcriptionProviderRaw) {
                    ForEach(TranscriptionProviderKind.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            SettingsComponents.divider()

            SettingsComponents.rowWithDescription(
                icon: "text.sparkles",
                title: String(localized: "Melhorar texto"),
                description: String(localized: "Pontua, reescreve e traduz quando solicitado.")
            ) {
                Picker("", selection: $llmProviderRaw) {
                    ForEach(LLMProviderKind.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            SettingsComponents.divider()

            SettingsComponents.rowWithDescription(
                icon: "arrow.triangle.2.circlepath",
                title: String(localized: "Fallback local"),
                description: String(localized: "Se a Groq falhar, tenta MLX Whisper local antes de desistir.")
            ) {
                Toggle("", isOn: $groqFallbackToLocal)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var modelsCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Modelos"))

            if usesGroq {
                SettingsComponents.rowWithDescription(
                    icon: "waveform.path.ecg",
                    title: String(localized: "Modelo de transcrição via Groq"),
                    description: String(localized: "Turbo é o padrão rápido e barato.")
                ) {
                    Picker("", selection: $groqWhisperModel) {
                        Text("whisper-large-v3-turbo").tag("whisper-large-v3-turbo")
                        Text("whisper-large-v3").tag("whisper-large-v3")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                SettingsComponents.divider()

                SettingsComponents.rowWithDescription(
                    icon: "sparkles",
                    title: String(localized: "Modelo de texto via Groq"),
                    description: String(localized: "20B é o melhor padrão para ditado: rápido e barato.")
                ) {
                    Picker("", selection: $groqLLMModel) {
                        Text("openai/gpt-oss-20b").tag("openai/gpt-oss-20b")
                        Text("openai/gpt-oss-120b").tag("openai/gpt-oss-120b")
                        Text("llama-3.1-8b-instant").tag("llama-3.1-8b-instant")
                        Text("llama-3.3-70b-versatile").tag("llama-3.3-70b-versatile")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            if usesLocalLLM {
                if usesGroq {
                    SettingsComponents.divider()
                }
                SettingsComponents.rowWithDescription(
                    icon: "cpu",
                    title: String(localized: "Modelo Ollama"),
                    description: String(localized: "Nome do modelo local já disponível no Ollama.")
                ) {
                    TextField(String(localized: "llama3.1"), text: $localLLMModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
        }
    }

    private func refreshGroqKeyState() {
        do {
            hasGroqAPIKey = try GroqCredentialStore().apiKey() != nil
        } catch {
            hasGroqAPIKey = false
            groqStatusMessage = error.localizedDescription
            groqStatusIsError = true
        }
    }

    private func saveGroqAPIKey() {
        do {
            try GroqCredentialStore().save(apiKey: groqAPIKeyInput)
            groqAPIKeyInput = ""
            hasGroqAPIKey = true
            groqStatusMessage = String(localized: "Chave salva.")
            groqStatusIsError = false
        } catch {
            groqStatusMessage = error.localizedDescription
            groqStatusIsError = true
        }
    }

    private func deleteGroqAPIKey() {
        do {
            try GroqCredentialStore().deleteAPIKey()
            groqAPIKeyInput = ""
            hasGroqAPIKey = false
            groqStatusMessage = String(localized: "Chave apagada.")
            groqStatusIsError = false
        } catch {
            groqStatusMessage = error.localizedDescription
            groqStatusIsError = true
        }
    }

    private func testGroqConnection() {
        isTestingGroq = true
        groqStatusMessage = nil
        Task {
            do {
                try await GroqClient().testAuthentication()
                await MainActor.run {
                    isTestingGroq = false
                    groqStatusMessage = String(localized: "Conexão OK.")
                    groqStatusIsError = false
                }
            } catch {
                await MainActor.run {
                    isTestingGroq = false
                    groqStatusMessage = error.localizedDescription
                    groqStatusIsError = true
                }
            }
        }
    }
}

#Preview {
    AISettingsSheetView(
        modalSize: CGSize(width: SettingsModalLayout.maxWidth, height: SettingsModalLayout.maxHeight)
    )
}
