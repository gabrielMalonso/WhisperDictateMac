import SwiftData
import SwiftUI

// MARK: - Supported Language

private enum SupportedLanguage: String, CaseIterable, Identifiable {
    case auto
    case pt
    case en
    case es
    case fr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: String(localized: "Auto-detectar")
        case .pt: String(localized: "Português")
        case .en: String(localized: "English")
        case .es: String(localized: "Español")
        case .fr: String(localized: "Français")
        }
    }
}

// MARK: - Translation Target

private enum TranslationTarget: String, CaseIterable, Identifiable {
    case pt, en, es, fr, de, it, ja, zh, ko

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pt: String(localized: "Português")
        case .en: String(localized: "English")
        case .es: String(localized: "Español")
        case .fr: String(localized: "Français")
        case .de: String(localized: "Deutsch")
        case .it: String(localized: "Italiano")
        case .ja: String(localized: "日本語")
        case .zh: String(localized: "中文")
        case .ko: String(localized: "한국어")
        }
    }
}

// MARK: - DictateSettingsView

struct DictateSettingsView: View {
    @AppStorage(MacAppKeys.aiMode, store: .app)
    private var aiModeRaw: String = AIMode.local.rawValue

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

    @AppStorage(MacAppKeys.transcriptionLanguage, store: .app)
    private var selectedLanguage: String = DeviceLanguageMapper.deviceDefault

    @AppStorage(MacAppKeys.translationEnabled, store: .app)
    private var translationEnabled: Bool = false

    @AppStorage(MacAppKeys.translationTargetLanguage, store: .app)
    private var translationTargetLanguage: String = "en"

    @State private var formattingOptions = FormattingOptions.load()
    @State private var groqAPIKeyInput = ""
    @State private var hasGroqAPIKey = false
    @State private var groqStatusMessage: String?
    @State private var groqStatusIsError = false
    @State private var isTestingGroq = false

    @Query(filter: #Predicate<ReplacementRule> { $0.isEnabled })
    private var activeRules: [ReplacementRule]

    @Query
    private var dictionaryEntries: [DictionaryEntry]

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsComponents.brandedHeader("DictateOSS")

                aiModeCard
                transcricaoCard
                traducaoCard
            }
            .padding(32)
        }
        .detailCardStyle()
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onChange(of: selectedLanguage) { _, _ in
            persistSettings()
        }
        .onChange(of: aiModeRaw) { _, _ in persistSettings() }
        .onChange(of: transcriptionProviderRaw) { _, _ in persistSettings() }
        .onChange(of: llmProviderRaw) { _, _ in persistSettings() }
        .onChange(of: groqWhisperModel) { _, _ in persistSettings() }
        .onChange(of: groqLLMModel) { _, _ in persistSettings() }
        .onChange(of: localLLMModel) { _, _ in persistSettings() }
        .onChange(of: groqFallbackToLocal) { _, _ in persistSettings() }
        .onChange(of: translationEnabled) { _, _ in
            sanitizeTranslationState()
            persistSettings()
        }
        .onChange(of: translationTargetLanguage) { _, _ in persistSettings() }
        .task {
            clearDeprecatedTranscriptionDomainIfNeeded()
            sanitizeUnavailableFeatures()
            refreshGroqKeyState()
        }
    }

    // MARK: - AI Mode Card

    private var aiModeCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Modo de IA"))

            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: $aiModeRaw) {
                    ForEach(AIMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Text(currentAIMode.detail)
                    .font(SettingsComponents.helperFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if currentAIMode == .custom {
                customProviderRows
            }

            if usesGroq {
                SettingsComponents.divider()
                groqSettingsSection
            }

            if usesLocalLLM {
                SettingsComponents.divider()
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

    private var customProviderRows: some View {
        Group {
            SettingsComponents.divider()
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
                title: String(localized: "LLM"),
                description: String(localized: "Use para reescrever, pontuar e traduzir o texto ditado.")
            ) {
                Picker("", selection: $llmProviderRaw) {
                    ForEach(LLMProviderKind.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    private var groqSettingsSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.rowWithDescription(
                icon: hasGroqAPIKey ? "key.fill" : "key",
                title: String(localized: "Chave da Groq"),
                description: hasGroqAPIKey
                    ? String(localized: "Chave salva no Keychain.")
                    : String(localized: "A chave fica no Keychain, não em UserDefaults.")
            ) {
                HStack(spacing: 8) {
                    SecureField(String(localized: "gsk_..."), text: $groqAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    Button(String(localized: "Salvar")) {
                        saveGroqAPIKey()
                    }
                    .disabled(groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(String(localized: "Apagar")) {
                        deleteGroqAPIKey()
                    }
                    .disabled(!hasGroqAPIKey)
                }
            }

            SettingsComponents.divider()

            SettingsComponents.rowWithDescription(
                icon: "waveform.path.ecg",
                title: String(localized: "Modelo Whisper"),
                description: String(localized: "Turbo é o padrão rápido e barato.")
            ) {
                Picker("", selection: $groqWhisperModel) {
                    Text("whisper-large-v3-turbo").tag("whisper-large-v3-turbo")
                    Text("whisper-large-v3").tag("whisper-large-v3")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if currentAIMode == .groq || selectedLLMProvider == .groq {
                SettingsComponents.divider()
                SettingsComponents.rowWithDescription(
                    icon: "sparkles",
                    title: String(localized: "Modelo LLM"),
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

            SettingsComponents.divider()

            HStack(spacing: 12) {
                Button {
                    testGroqConnection()
                } label: {
                    if isTestingGroq {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(String(localized: "Testar conexão"))
                    }
                }
                .disabled(!hasGroqAPIKey || isTestingGroq)

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

    // MARK: - Transcription Card

    private var transcricaoCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Transcrição"))
                // Language
                SettingsComponents.rowWithDescription(
                    icon: "globe",
                    title: String(localized: "Idioma"),
                    description: String(localized: "Se você mistura idiomas ao falar, recomendamos utilizar \"Auto-detectar\".")
                ) {
                    Picker("", selection: $selectedLanguage) {
                        ForEach(SupportedLanguage.allCases) { lang in
                            Text(lang.label).tag(lang.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                SettingsComponents.divider()

                // Tone
                HStack(spacing: SettingsComponents.rowSpacing) {
                    Image(systemName: "text.quote")
                        .font(.body)
                        .foregroundStyle(accentColor)
                        .frame(width: SettingsComponents.rowIconWidth)

                    Text(String(localized: "Tom"))
                        .font(SettingsComponents.rowFont)

                    Spacer()

                    Picker("", selection: $formattingOptions.tone) {
                        ForEach(Tone.allCases, id: \.self) { tone in
                            Text(toneLabel(tone)).tag(tone)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: formattingOptions.tone) { _, newValue in
                        if FeatureAvailability.canUseTone(newValue) {
                            formattingOptions.save()
                            persistSettings()
                        } else {
                            formattingOptions.tone = .natural
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, SettingsComponents.rowHorizontalPadding)

                SettingsComponents.divider()

                // Replacement Rules
                NavigationLink(value: DetailRoute.replacementRules) {
                    SettingsComponents.row(
                        icon: "arrow.left.arrow.right",
                        title: String(localized: "Regras de Substituição")
                    ) {
                        HStack(spacing: 8) {
                            Text(AppText.rulesCount(activeRules.count))
                                .font(AppTypography.helper)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accentColor.opacity(0.08))
                                .foregroundStyle(accentColor)
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                SettingsComponents.divider()

                // Dictionary
                NavigationLink(value: DetailRoute.dictionary) {
                    SettingsComponents.row(
                        icon: "character.book.closed",
                        title: String(localized: "Dicionário Pessoal")
                    ) {
                        HStack(spacing: 8) {
                            Text(AppText.termsCount(dictionaryEntries.count))
                                .font(AppTypography.helper)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accentColor.opacity(0.08))
                                .foregroundStyle(accentColor)
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                SettingsComponents.divider()

                // Formatting toggles
                SettingsComponents.row(icon: "text.alignleft", title: String(localized: "Parágrafos")) {
                    Toggle("", isOn: $formattingOptions.addParagraphs)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .onChange(of: formattingOptions.addParagraphs) { _, _ in
                    formattingOptions.save()
                    persistSettings()
                }

                SettingsComponents.divider()

                SettingsComponents.row(icon: "textformat.abc.dottedunderline", title: String(localized: "Remover ponto final")) {
                    Toggle("", isOn: $formattingOptions.removeFinalPeriod)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .onChange(of: formattingOptions.removeFinalPeriod) { _, _ in
                    formattingOptions.save()
                    persistSettings()
                }

                SettingsComponents.divider()

                SettingsComponents.row(icon: "calendar", title: String(localized: "Formatar datas")) {
                    Toggle("", isOn: $formattingOptions.formatDates)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .onChange(of: formattingOptions.formatDates) { _, _ in
                    formattingOptions.save()
                    persistSettings()
                }

                SettingsComponents.divider()

                SettingsComponents.row(icon: "clock", title: String(localized: "Formatar horários")) {
                    Toggle("", isOn: $formattingOptions.formatTimes)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .onChange(of: formattingOptions.formatTimes) { _, _ in
                    formattingOptions.save()
                    persistSettings()
                }

                SettingsComponents.divider()

                SettingsComponents.row(icon: "list.bullet", title: String(localized: "Formatar listas")) {
                    Toggle("", isOn: $formattingOptions.formatLists)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .onChange(of: formattingOptions.formatLists) { _, _ in
                    formattingOptions.save()
                    persistSettings()
                }

        }
    }

    // MARK: - Translation Card

    private var traducaoCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Tradução"))
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.body)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Ativar tradução"))
                            .font(AppTypography.row.weight(.medium))
                        Text(String(localized: "Habilita a hotkey de tradução com o idioma selecionado"))
                            .font(AppTypography.helper)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if FeatureAvailability.canUseTranslation {
                        Toggle("", isOn: $translationEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    } else {
                        Label(String(localized: "Em breve"), systemImage: "clock")
                            .font(AppTypography.helper.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)

                if FeatureAvailability.canUseTranslation && translationEnabled {
                    SettingsComponents.divider()

                    SettingsComponents.row(
                        icon: "bubble.left.and.bubble.right",
                        title: String(localized: "Traduzir para")
                    ) {
                        Picker("", selection: $translationTargetLanguage) {
                            ForEach(TranslationTarget.allCases) { target in
                                Text(target.label).tag(target.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
        }

    // MARK: - Helpers

    private var currentAIMode: AIMode {
        AIMode(rawValue: aiModeRaw) ?? .local
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

    private func toneLabel(_ tone: Tone) -> String {
        switch tone {
        case .colloquial: String(localized: "Coloquial")
        case .natural: String(localized: "Natural")
        case .formal: String(localized: "Formal")
        }
    }

    private func persistSettings() {
        // Local-only build: settings are stored in UserDefaults/SwiftData.
    }

    private func sanitizeTranslationState() {
        if translationEnabled, !FeatureAvailability.canUseTranslation {
            translationEnabled = false
        }
    }

    private func sanitizeToneState() {
        guard !FeatureAvailability.canUseTone(formattingOptions.tone) else { return }
        formattingOptions.tone = .natural
        formattingOptions.save()
    }

    private func sanitizeUnavailableFeatures() {
        let previousTranslationEnabled = translationEnabled
        let previousTone = formattingOptions.tone

        sanitizeTranslationState()
        sanitizeToneState()

        if translationEnabled != previousTranslationEnabled || formattingOptions.tone != previousTone {
            persistSettings()
        }
    }

    private func clearDeprecatedTranscriptionDomainIfNeeded() {
        if UserDefaults.app.object(forKey: MacAppKeys.transcriptionDomain) != nil {
            UserDefaults.app.removeObject(forKey: MacAppKeys.transcriptionDomain)
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
    DictateSettingsView()
        .frame(width: 600, height: 800)
}
