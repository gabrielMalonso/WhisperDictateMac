import AppKit
import CoreGraphics

enum ClipboardPasterError: LocalizedError {
    case accessibilityNotGranted
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Permissao de Acessibilidade necessaria para colar no app ativo."
        case .pasteFailed:
            return "Nao foi possivel simular Command+V."
        }
    }
}

final class ClipboardPaster {
    private struct SavedItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let pasteboard = NSPasteboard.general

    func paste(_ text: String, restoreClipboard: Bool) async throws {
        guard AXIsProcessTrusted() else {
            throw ClipboardPasterError.accessibilityNotGranted
        }

        let savedItems = restoreClipboard ? savePasteboard() : []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard sendPasteShortcut() else {
            if restoreClipboard {
                restorePasteboard(savedItems)
            }
            throw ClipboardPasterError.pasteFailed
        }

        try await Task.sleep(for: .milliseconds(220))

        if restoreClipboard {
            restorePasteboard(savedItems)
        }
    }

    private func savePasteboard() -> [SavedItem] {
        guard let types = pasteboard.types else { return [] }

        return types.compactMap { type in
            guard let data = pasteboard.data(forType: type), shouldPreserve(type) else {
                return nil
            }
            return SavedItem(type: type, data: data)
        }
    }

    private func restorePasteboard(_ items: [SavedItem]) {
        pasteboard.clearContents()
        for item in items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }

    private func shouldPreserve(_ type: NSPasteboard.PasteboardType) -> Bool {
        let raw = type.rawValue
        return !raw.hasPrefix("dyn.") && raw != NSPasteboard.PasteboardType.fileURL.rawValue
    }

    private func sendPasteShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

