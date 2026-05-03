import SwiftUI

struct ToolsSettingsSheetView: View {
    @AppStorage(MacAppKeys.mlxExecutablePath, store: .app)
    private var mlxExecutablePath: String = AppConfig.defaultMLXExecutablePath

    @AppStorage(MacAppKeys.mlxModel, store: .app)
    private var mlxModel: String = AppConfig.defaultMLXModel

    @AppStorage(MacAppKeys.localFormattingLLMEnabled, store: .app)
    private var localFormattingEnabled: Bool = true

    @AppStorage(MacAppKeys.localFormattingLLMEndpoint, store: .app)
    private var localFormattingEndpoint: String = AppConfig.defaultLocalFormattingLLMEndpoint

    @AppStorage(MacAppKeys.localFormattingLLMModel, store: .app)
    private var localFormattingModel: String = AppConfig.defaultLocalFormattingLLMModel

    @AppStorage(MacAppKeys.localFormattingLLMTimeoutSeconds, store: .app)
    private var localFormattingTimeoutSeconds: Double = LocalLLMConfiguration.defaultTimeoutSeconds

    @AppStorage(MacAppKeys.localFormattingMinChars, store: .app)
    private var localFormattingMinChars: Int = LocalLLMConfiguration.defaultMinCharsToFormat

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var refreshID = UUID()
    @State private var downloadingModels: Set<String> = []
    @State private var deletingModels: Set<String> = []
    @State private var deletionTargetModel: String?
    @State private var modelManagementError: String?
    @State private var installedOllamaModels: [String] = []
    @State private var ollamaStatusMessage: String?
    @State private var isCheckingOllama = false
    @State private var isTestingFormatting = false
    @State private var formattingTestMessage: String?

    let modalSize: CGSize

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private var resolvedExecutablePath: String? {
        ExecutableResolver.resolve(mlxExecutablePath, fallbackName: "mlx_whisper")
    }

    private var executableIsReady: Bool {
        resolvedExecutablePath != nil
    }

    private var localLLMConfiguration: LocalLLMConfiguration {
        LocalLLMConfiguration(
            isEnabled: localFormattingEnabled,
            endpoint: localFormattingEndpoint,
            model: localFormattingModel,
            timeoutSeconds: localFormattingTimeoutSeconds,
            minCharsToFormat: localFormattingMinChars,
            temperature: LocalLLMConfiguration.defaultTemperature
        )
    }

    private var localEndpointIsValid: Bool {
        localLLMConfiguration.isLocalEndpoint
    }

    private var selectedOllamaModelIsInstalled: Bool {
        installedOllamaModels.contains(localFormattingModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard
                executableCard
                modelCard
                formattingLLMCard
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
        .id(refreshID)
        .task(id: refreshID) {
            await refreshOllamaStatus()
        }
        .confirmationDialog(
            String(localized: "Excluir modelo?"),
            isPresented: Binding(
                get: { deletionTargetModel != nil },
                set: { isPresented in
                    if !isPresented {
                        deletionTargetModel = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Excluir do cache"), role: .destructive) {
                deletePendingModel()
            }
            Button(String(localized: "Cancelar"), role: .cancel) {
                deletionTargetModel = nil
            }
        } message: {
            Text(deletionTargetModel ?? "")
        }
        .alert(
            String(localized: "Não deu para gerenciar o modelo"),
            isPresented: Binding(
                get: { modelManagementError != nil },
                set: { isPresented in
                    if !isPresented {
                        modelManagementError = nil
                    }
                }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                modelManagementError = nil
            }
        } message: {
            Text(modelManagementError ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Ferramentas"))
                .font(.system(size: 28, weight: .bold, design: .serif))

            Spacer()

            Button {
                refreshID = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Atualizar status"))
        }
    }

    private var statusCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "MLX Whisper"))

            statusRow(
                icon: executableIsReady ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: executableIsReady
                    ? String(localized: "Executável encontrado")
                    : String(localized: "Executável não encontrado"),
                detail: resolvedExecutablePath ?? String(localized: "Instale mlx-whisper ou ajuste o caminho abaixo."),
                color: executableIsReady ? .green : .red
            )

            SettingsComponents.divider()

            modelStatusRow
        }
    }

    private var executableCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Executável"))

            VStack(alignment: .leading, spacing: 10) {
                TextField(String(localized: "Caminho do mlx_whisper"), text: $mlxExecutablePath)
                    .textFieldStyle(.roundedBorder)
                    .font(SettingsComponents.rowFont)

                HStack {
                    Button(String(localized: "Usar detectado")) {
                        if let resolvedExecutablePath {
                            mlxExecutablePath = resolvedExecutablePath
                        } else if let detected = ExecutableResolver.resolve("mlx_whisper", fallbackName: "mlx_whisper") {
                            mlxExecutablePath = detected
                        }
                    }
                    .disabled(ExecutableResolver.resolve("mlx_whisper", fallbackName: "mlx_whisper") == nil)

                    Button(String(localized: "Restaurar padrão")) {
                        mlxExecutablePath = AppConfig.defaultMLXExecutablePath
                    }

                    Spacer()
                }
                .buttonStyle(.borderless)
                .font(SettingsComponents.helperFont)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var modelCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Modelos"))

            VStack(spacing: 0) {
                ForEach(MLXWhisperModelCatalog.presets) { preset in
                    modelPresetRow(preset)

                    if preset.id != MLXWhisperModelCatalog.presets.last?.id {
                        SettingsComponents.divider()
                    }
                }
            }

            modelDownloadFootnote

            SettingsComponents.divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Modelo personalizado"))
                    .font(SettingsComponents.rowFont)

                TextField(String(localized: "mlx-community/whisper-large-v3-turbo ou caminho local"), text: $mlxModel)
                    .textFieldStyle(.roundedBorder)

                if let cachePath = MLXWhisperModelCatalog.huggingFaceCachePath(for: mlxModel) {
                    Text(cachePath)
                        .font(SettingsComponents.helperFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var formattingLLMCard: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "LLM de formatação"))

            SettingsComponents.rowWithDescription(
                icon: "sparkles",
                title: String(localized: "Ativar formatação local"),
                description: String(localized: "Usa uma LLM local depois do Whisper e antes do dicionário/regras.")
            ) {
                Toggle("", isOn: $localFormattingEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            SettingsComponents.divider()

            ollamaStatusRow

            SettingsComponents.divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Endpoint do Ollama"))
                    .font(SettingsComponents.rowFont)

                TextField(String(localized: "http://localhost:11434"), text: $localFormattingEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .font(SettingsComponents.rowFont)

                HStack {
                    Button(String(localized: "Restaurar padrão")) {
                        localFormattingEndpoint = LocalLLMConfiguration.defaultEndpoint
                    }
                    Button(String(localized: "Atualizar modelos")) {
                        Task { await refreshOllamaStatus() }
                    }
                    Spacer()
                }
                .buttonStyle(.borderless)
                .font(SettingsComponents.helperFont)

                if !localEndpointIsValid {
                    Label(String(localized: "Somente endpoints locais são permitidos."), systemImage: "lock")
                        .font(SettingsComponents.helperFont)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            SettingsComponents.divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Modelo de formatação"))
                    .font(SettingsComponents.rowFont)

                TextField(String(localized: "qwen2.5:3b"), text: $localFormattingModel)
                    .textFieldStyle(.roundedBorder)
                    .font(SettingsComponents.rowFont)

                if !installedOllamaModels.isEmpty {
                    Picker(String(localized: "Modelos instalados"), selection: $localFormattingModel) {
                        ForEach(installedOllamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Label(
                    selectedOllamaModelIsInstalled
                        ? String(localized: "Modelo instalado no Ollama.")
                        : String(localized: "Baixe com: ollama pull \(localFormattingModel)"),
                    systemImage: selectedOllamaModelIsInstalled ? "checkmark.circle" : "arrow.down.circle"
                )
                .font(SettingsComponents.helperFont)
                .foregroundStyle(selectedOllamaModelIsInstalled ? .green : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            SettingsComponents.divider()

            SettingsComponents.row(icon: "textformat.size", title: String(localized: "Caracteres mínimos")) {
                Stepper("\(localFormattingMinChars)", value: $localFormattingMinChars, in: 0...2_000, step: 25)
                    .labelsHidden()
                    .frame(width: 110)
            }

            SettingsComponents.divider()

            SettingsComponents.row(icon: "timer", title: String(localized: "Timeout")) {
                Stepper("\(Int(localFormattingTimeoutSeconds))s", value: $localFormattingTimeoutSeconds, in: 5...120, step: 5)
                    .labelsHidden()
                    .frame(width: 110)
            }

            SettingsComponents.divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        testFormatting()
                    } label: {
                        if isTestingFormatting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(String(localized: "Testar formatação"), systemImage: "checkmark.seal")
                        }
                    }
                    .disabled(isTestingFormatting || !localEndpointIsValid)

                    Spacer()
                }

                if let formattingTestMessage {
                    Text(formattingTestMessage)
                        .font(SettingsComponents.helperFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var ollamaStatusRow: some View {
        let ready = localEndpointIsValid && !installedOllamaModels.isEmpty
        return HStack(spacing: 12) {
            if isCheckingOllama {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24)
            } else {
                Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(ready ? .green : .red)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ready ? String(localized: "Ollama encontrado") : String(localized: "Ollama não encontrado"))
                    .font(SettingsComponents.rowFont)
                Text(ollamaStatusMessage ?? localFormattingEndpoint)
                    .font(SettingsComponents.helperFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func statusRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SettingsComponents.rowFont)
                Text(detail)
                    .font(SettingsComponents.helperFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var modelStatusRow: some View {
        let isDownloading = downloadingModels.contains(mlxModel)
        let isInstalled = MLXWhisperModelCatalog.isInstalled(mlxModel)

        return HStack(spacing: 12) {
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24)
            } else {
                Image(systemName: isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.body)
                    .foregroundStyle(isInstalled ? .green : accentColor)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isDownloading ? String(localized: "Baixando modelo") : MLXWhisperModelCatalog.installStateLabel(for: mlxModel))
                    .font(SettingsComponents.rowFont)
                Text(mlxModel)
                    .font(SettingsComponents.helperFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func modelPresetRow(_ preset: MLXWhisperModelPreset) -> some View {
        let isSelected = mlxModel == preset.id
        let isInstalled = MLXWhisperModelCatalog.isInstalled(preset.id)
        let isDownloading = downloadingModels.contains(preset.id)
        let isDeleting = deletingModels.contains(preset.id)

        return HStack(spacing: 12) {
            Button {
                mlxModel = preset.id
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.body)
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(preset.name)
                                .font(SettingsComponents.rowFont)

                            Text(preset.approximateSize)
                                .font(SettingsComponents.helperFont)
                                .foregroundStyle(.secondary)
                        }

                        Text(preset.detail)
                            .font(SettingsComponents.helperFont)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            if isDownloading {
                Text(String(localized: "Baixando"))
                    .font(SettingsComponents.helperFont.weight(.medium))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            } else if isDeleting {
                Text(String(localized: "Excluindo"))
                    .font(SettingsComponents.helperFont.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: 22, height: 22)
                    .help(String(localized: "Modelo instalado"))
            }

            modelDownloadButton(for: preset.id, isInstalled: isInstalled, isDownloading: isDownloading, isDeleting: isDeleting)
            modelDeleteButton(for: preset.id, isInstalled: isInstalled, isDownloading: isDownloading, isDeleting: isDeleting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var modelDownloadFootnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(SettingsComponents.helperFont)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text(String(localized: "Modelos ainda não baixados serão baixados automaticamente no primeiro uso. Se quiser evitar espera na primeira transcrição, use o botão de download agora."))
                .font(SettingsComponents.helperFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025))
    }

    private func modelDownloadButton(for model: String, isInstalled: Bool, isDownloading: Bool, isDeleting: Bool) -> some View {
        Group {
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .help(String(localized: "Baixando modelo"))
            } else {
                Button {
                    downloadModel(model)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(accentColor)
                .disabled(isInstalled || isDeleting || !executableIsReady)
                .opacity(isInstalled || isDeleting ? 0.35 : 1)
                .help(
                    executableIsReady
                        ? String(localized: "Baixar modelo")
                        : String(localized: "Configure o executável antes de baixar")
                )
            }
        }
        .frame(width: 30, height: 30)
    }

    private func modelDeleteButton(for model: String, isInstalled: Bool, isDownloading: Bool, isDeleting: Bool) -> some View {
        Group {
            if isDeleting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .help(String(localized: "Excluindo modelo"))
            } else {
                Button {
                    deletionTargetModel = model
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isInstalled ? .red.opacity(0.85) : .secondary)
                .disabled(!isInstalled || isDownloading)
                .opacity(isInstalled ? 1 : 0.35)
                .help(String(localized: "Excluir modelo baixado"))
            }
        }
        .frame(width: 30, height: 30)
    }

    private func downloadModel(_ model: String) {
        guard !downloadingModels.contains(model) else { return }

        downloadingModels.insert(model)

        Task {
            do {
                try await MLXWhisperModelManager.download(model: model, executablePath: mlxExecutablePath)
                await MainActor.run {
                    downloadingModels.remove(model)
                    refreshID = UUID()
                }
            } catch {
                await MainActor.run {
                    downloadingModels.remove(model)
                    modelManagementError = error.localizedDescription
                }
            }
        }
    }

    private func deletePendingModel() {
        guard let model = deletionTargetModel else { return }
        guard !deletingModels.contains(model) else { return }

        deletionTargetModel = nil
        deletingModels.insert(model)

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try MLXWhisperModelManager.delete(model: model)
                }.value

                await MainActor.run {
                    deletingModels.remove(model)
                    refreshID = UUID()
                }
            } catch {
                await MainActor.run {
                    deletingModels.remove(model)
                    modelManagementError = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func refreshOllamaStatus() async {
        isCheckingOllama = true
        defer { isCheckingOllama = false }

        guard localEndpointIsValid else {
            installedOllamaModels = []
            ollamaStatusMessage = String(localized: "Somente endpoints locais são permitidos.")
            return
        }

        do {
            let models = try await OllamaLocalLLMClient().installedModels(configuration: localLLMConfiguration)
            installedOllamaModels = models
            if models.isEmpty {
                ollamaStatusMessage = String(localized: "Ollama respondeu, mas nenhum modelo foi encontrado.")
            } else {
                ollamaStatusMessage = String(localized: "\(models.count) modelo(s) instalado(s).")
            }
        } catch {
            installedOllamaModels = []
            ollamaStatusMessage = error.localizedDescription
        }
    }

    private func testFormatting() {
        guard !isTestingFormatting else { return }
        isTestingFormatting = true
        formattingTestMessage = nil

        Task {
            let sample = String(localized: "olá pessoal então amanhã às nove horas eu vou revisar os itens um dois e três.")
            let options = FormattingOptions.default
            let result = await LocalFormattingService().format(
                rawText: sample,
                options: options,
                language: "pt",
                defaults: UserDefaults.app
            )
            await MainActor.run {
                isTestingFormatting = false
                formattingTestMessage = result
            }
        }
    }
}

#Preview {
    ToolsSettingsSheetView(
        modalSize: CGSize(width: SettingsModalLayout.maxWidth, height: SettingsModalLayout.maxHeight)
    )
}
