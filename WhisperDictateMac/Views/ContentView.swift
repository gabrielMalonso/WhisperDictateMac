import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: DictationController
    @AppStorage(AppSettings.mlxExecutablePathKey, store: AppSettings.defaults)
    private var executablePath = AppSettings.defaultMLXExecutablePath
    @AppStorage(AppSettings.mlxModelKey, store: AppSettings.defaults)
    private var model = AppSettings.defaultMLXModel
    @AppStorage(AppSettings.languageKey, store: AppSettings.defaults)
    private var language = "pt"
    @AppStorage(AppSettings.restoreClipboardKey, store: AppSettings.defaults)
    private var restoreClipboard = true

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            statusPanel

            settings

            dependencyPanel

            Spacer(minLength: 0)
        }
        .padding(28)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Whisper Dictate")
                    .font(.system(size: 32, weight: .bold))

                Text("Ditado local com MLX Whisper. Sem conta. Sem backend. Sem novela.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(controller.primaryActionTitle) {
                Task { await controller.toggleDictation() }
            }
            .keyboardShortcut("d", modifiers: [.control, .shift])
            .disabled(controller.state == .transcribing)
            .controlSize(.large)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(controller.statusText, systemImage: controller.statusIcon)
                    .font(.headline)

                Spacer()

                if controller.state == .recording {
                    Text(controller.elapsedText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if controller.state == .recording {
                ProgressView(value: Double(controller.currentAmplitude), total: 1)
                    .progressViewStyle(.linear)
            }

            if let lastTranscript = controller.lastTranscript {
                Divider()
                Text(lastTranscript)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(6)
            }

            if let errorMessage = controller.errorMessage {
                Divider()
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var settings: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                Text("MLX CLI")
                    .foregroundStyle(.secondary)
                TextField("Caminho do mlx_whisper", text: $executablePath)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Modelo")
                    .foregroundStyle(.secondary)
                TextField("Ex: mlx-community/whisper-large-v3-turbo", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Idioma")
                    .foregroundStyle(.secondary)
                TextField("pt, en, es ou vazio para auto", text: $language)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }

            GridRow {
                Text("Clipboard")
                    .foregroundStyle(.secondary)
                Toggle("Restaurar clipboard depois de colar", isOn: $restoreClipboard)
            }
        }
    }

    private var dependencyPanel: some View {
        let status = dependencyStatus

        return VStack(alignment: .leading, spacing: 12) {
            Label(
                status.isReady ? "Dependencias prontas" : "Falta configurar: \(status.missingItems.joined(separator: ", "))",
                systemImage: status.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(status.isReady ? .green : .orange)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                dependencyRow("MLX CLI", value: status.mlxExecutablePath)
                dependencyRow("ffmpeg", value: status.ffmpegPath)
                dependencyRow("Modelo", value: status.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : status.model)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func dependencyRow(_ title: String, value: String?) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value ?? "Nao encontrado")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(value == nil ? .red : .primary)
        }
    }

    private var dependencyStatus: DependencyStatus {
        DependencyChecker.check(
            configuration: WhisperConfiguration(
                executablePath: executablePath,
                model: model,
                language: language
            )
        )
    }
}
