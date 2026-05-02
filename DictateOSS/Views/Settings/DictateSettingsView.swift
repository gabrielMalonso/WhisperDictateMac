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
    @AppStorage(MacAppKeys.transcriptionLanguage, store: .app)
    private var selectedLanguage: String = DeviceLanguageMapper.deviceDefault

    @AppStorage(MacAppKeys.translationEnabled, store: .app)
    private var translationEnabled: Bool = false

    @AppStorage(MacAppKeys.translationTargetLanguage, store: .app)
    private var translationTargetLanguage: String = "en"

    @State private var formattingOptions = FormattingOptions.load()

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
        .onChange(of: translationEnabled) { _, _ in
            sanitizeTranslationState()
            persistSettings()
        }
        .onChange(of: translationTargetLanguage) { _, _ in persistSettings() }
        .task {
            clearDeprecatedTranscriptionDomainIfNeeded()
            sanitizeUnavailableFeatures()
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
}

#Preview {
    DictateSettingsView()
        .frame(width: 600, height: 800)
}
