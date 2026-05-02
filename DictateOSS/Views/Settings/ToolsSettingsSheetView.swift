import SwiftUI

struct ToolsSettingsSheetView: View {
    @AppStorage(MacAppKeys.mlxExecutablePath, store: .app)
    private var mlxExecutablePath: String = AppConfig.defaultMLXExecutablePath

    @AppStorage(MacAppKeys.mlxModel, store: .app)
    private var mlxModel: String = AppConfig.defaultMLXModel

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var refreshID = UUID()
    @State private var downloadingModels: Set<String> = []
    @State private var deletionTargetModel: String?
    @State private var modelManagementError: String?

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard
                executableCard
                modelCard
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
            } else if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: 22, height: 22)
                    .help(String(localized: "Modelo instalado"))
            }

            modelDownloadButton(for: preset.id, isInstalled: isInstalled, isDownloading: isDownloading)
            modelDeleteButton(for: preset.id, isInstalled: isInstalled, isDownloading: isDownloading)
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

    private func modelDownloadButton(for model: String, isInstalled: Bool, isDownloading: Bool) -> some View {
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
                .disabled(isInstalled || !executableIsReady)
                .opacity(isInstalled ? 0.35 : 1)
                .help(
                    executableIsReady
                        ? String(localized: "Baixar modelo")
                        : String(localized: "Configure o executável antes de baixar")
                )
            }
        }
        .frame(width: 30, height: 30)
    }

    private func modelDeleteButton(for model: String, isInstalled: Bool, isDownloading: Bool) -> some View {
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
        .frame(width: 30, height: 30)
    }

    private func downloadModel(_ model: String) {
        guard !downloadingModels.contains(model) else { return }

        mlxModel = model
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

        do {
            try MLXWhisperModelManager.delete(model: model)
            deletionTargetModel = nil
            refreshID = UUID()
        } catch {
            deletionTargetModel = nil
            modelManagementError = error.localizedDescription
        }
    }
}

#Preview {
    ToolsSettingsSheetView(
        modalSize: CGSize(width: SettingsModalLayout.maxWidth, height: SettingsModalLayout.maxHeight)
    )
}
