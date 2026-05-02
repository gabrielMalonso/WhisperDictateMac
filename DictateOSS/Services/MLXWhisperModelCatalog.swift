import Foundation

struct MLXWhisperModelPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let approximateSize: String
}

enum MLXWhisperModelCatalog {
    static let presets: [MLXWhisperModelPreset] = [
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-large-v3-turbo",
            name: "Large v3 Turbo",
            detail: "Recomendado para uso diario: bom equilibrio entre velocidade e precisao.",
            approximateSize: "1.61 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-large-v3-mlx",
            name: "Large v3",
            detail: "Prioriza precisao em transcricoes longas ou mais exigentes.",
            approximateSize: "~3 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-small-mlx",
            name: "Small",
            detail: "Opcao leve para respostas rapidas e Macs com recursos limitados.",
            approximateSize: "~1 GB"
        ),
        MLXWhisperModelPreset(
            id: "mlx-community/whisper-tiny",
            name: "Tiny",
            detail: "Indicado para validacao tecnica, nao para transcricao de producao.",
            approximateSize: "74 MB"
        )
    ]

    static func preset(for model: String) -> MLXWhisperModelPreset? {
        presets.first { $0.id == model.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func isInstalled(_ model: String) -> Bool {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("/") == false {
            return false
        }

        let expanded = ExecutableResolver.expandedPath(trimmed)
        if FileManager.default.fileExists(atPath: expanded) {
            return true
        }

        guard let cacheURL = huggingFaceCacheURL(for: trimmed) else {
            return false
        }

        let snapshotsURL = cacheURL.appendingPathComponent("snapshots", isDirectory: true)
        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return !snapshots.isEmpty
    }

    static func installStateLabel(for model: String) -> String {
        if isInstalled(model) {
            return String(localized: "Instalado")
        }
        return String(localized: "Baixa no primeiro uso")
    }

    static func huggingFaceCachePath(for model: String) -> String? {
        huggingFaceCacheURL(for: model)?.path
    }

    private static func huggingFaceCacheURL(for model: String) -> URL? {
        let parts = model.split(separator: "/")
        guard parts.count == 2 else { return nil }

        let hubRoot: URL
        if let hfHubCache = ProcessInfo.processInfo.environment["HUGGINGFACE_HUB_CACHE"], !hfHubCache.isEmpty {
            hubRoot = URL(fileURLWithPath: ExecutableResolver.expandedPath(hfHubCache), isDirectory: true)
        } else if let hfHome = ProcessInfo.processInfo.environment["HF_HOME"], !hfHome.isEmpty {
            hubRoot = URL(fileURLWithPath: ExecutableResolver.expandedPath(hfHome), isDirectory: true)
                .appendingPathComponent("hub", isDirectory: true)
        } else {
            hubRoot = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent(".cache/huggingface/hub", isDirectory: true)
        }

        let cacheName = "models--\(parts[0])--\(parts[1])"
        return hubRoot.appendingPathComponent(cacheName, isDirectory: true)
    }
}
