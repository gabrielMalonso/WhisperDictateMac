import Cocoa
import CoreGraphics
import os

// MARK: - Errors

enum ClipboardSwapError: Error, LocalizedError {
    case accessibilityNotGranted
    case pasteSimulationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return String(localized: "Permissão de Acessibilidade necessária para simular a colagem. Conceda acesso em Ajustes do Sistema.")
        case .pasteSimulationFailed:
            return String(localized: "Falha ao simular o evento de colagem ⌘V.")
        }
    }
}

struct ClipboardPasteStrategy: Equatable {
    let name: String
    let minimumRestoreDelayMs: Int

    static func resolve(for bundleID: String?) -> ClipboardPasteStrategy {
        switch bundleID {
        case "com.apple.finder":
            return ClipboardPasteStrategy(name: "finder_safe_delay", minimumRestoreDelayMs: 350)
        case "com.google.Chrome", "com.google.Chrome.canary":
            return ClipboardPasteStrategy(name: "browser_text_field", minimumRestoreDelayMs: 250)
        case "com.t3tools.t3code", "com.microsoft.VSCode", "com.cursor.Cursor":
            return ClipboardPasteStrategy(name: "editor", minimumRestoreDelayMs: 250)
        default:
            return ClipboardPasteStrategy(name: "default", minimumRestoreDelayMs: 200)
        }
    }
}

// MARK: - ClipboardSwapManager

final class ClipboardSwapManager {
    private static let logger = Logger(subsystem: "com.gmalonso.dictate-mac", category: "ClipboardSwapManager")
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("com.apple.is-transient")

    private let isAccessibilityTrusted: @Sendable () -> Bool
    private let pasteboard: NSPasteboard
    private let pasteAction: @Sendable () throws -> Void

    init(
        isAccessibilityTrusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        pasteboard: NSPasteboard = .general,
        pasteAction: (@Sendable () throws -> Void)? = nil
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.pasteboard = pasteboard
        self.pasteAction = pasteAction ?? Self.defaultPasteAction()
    }

    /// The delay in milliseconds before restoring the original clipboard content after pasting.
    private var restoreDelay: Int {
        AppConfig.defaultClipboardRestoreDelayMs
    }

    /// Pastes the given text into the currently focused application by:
    /// 1. Saving the current clipboard contents
    /// 2. Setting the clipboard to the transcribed text
    /// 3. Simulating ⌘V
    /// 4. Waiting for the paste to complete
    /// 5. Restoring the original clipboard contents
    func pasteText(_ text: String) async throws {
        let operationID = UUID().uuidString
        let targetApp = frontmostApplicationInfo()
        let strategy = ClipboardPasteStrategy.resolve(for: targetApp.bundleID)
        let effectiveRestoreDelay = max(self.restoreDelay, strategy.minimumRestoreDelayMs)
        let initialChangeCount = pasteboard.changeCount
        Self.logger.info(
            """
            [phase:clipboard_swap_started] operationId=\(operationID, privacy: .public) \
            chars=\(text.count) \
            configuredRestoreDelayMs=\(self.restoreDelay) \
            effectiveRestoreDelayMs=\(effectiveRestoreDelay) \
            targetApp=\(targetApp.description, privacy: .public) \
            strategy=\(strategy.name, privacy: .public) \
            initialChangeCount=\(initialChangeCount)
            """
        )

        // 1. Check Accessibility permission
        guard isAccessibilityTrusted() else {
            Self.logger.warning(
                "[phase:clipboard_swap_aborted] operationId=\(operationID, privacy: .public) reason=accessibility_not_granted"
            )
            throw ClipboardSwapError.accessibilityNotGranted
        }

        // 2. Save current pasteboard contents
        let savedItems = savePasteboard(pasteboard)
        Self.logger.info(
            "[phase:clipboard_saved] operationId=\(operationID, privacy: .public) itemCount=\(savedItems.count)"
        )

        // 3. Set pasteboard to transcribed text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: Self.concealedType)
        pasteboard.setData(Data(), forType: Self.transientType)
        let injectedChangeCount = pasteboard.changeCount
        Self.logger.info(
            """
            [phase:clipboard_injected] operationId=\(operationID, privacy: .public) \
            changeCount=\(injectedChangeCount) \
            targetApp=\(self.frontmostApplicationInfo().description, privacy: .public)
            """
        )

        do {
            // 4. Simulate ⌘V (paste)
            try pasteAction()
            Self.logger.info(
                "[phase:clipboard_paste_event_sent] operationId=\(operationID, privacy: .public)"
            )

            // 5. Wait for the target app to process the paste
            try await Task.sleep(for: .milliseconds(effectiveRestoreDelay))
            let changeCountBeforeRestore = pasteboard.changeCount
            Self.logger.info(
                """
                [phase:clipboard_restore_started] operationId=\(operationID, privacy: .public) \
                changeCount=\(changeCountBeforeRestore) \
                mutatedDuringWindow=\(changeCountBeforeRestore != injectedChangeCount) \
                targetApp=\(self.frontmostApplicationInfo().description, privacy: .public)
                """
            )

            // 6. Restore original pasteboard contents
            restorePasteboard(pasteboard, from: savedItems)
            Self.logger.info(
                """
                [phase:clipboard_restore_completed] operationId=\(operationID, privacy: .public) \
                restoredItemCount=\(savedItems.count) \
                finalChangeCount=\(self.pasteboard.changeCount)
                """
            )
        } catch {
            restorePasteboard(pasteboard, from: savedItems)
            Self.logger.warning(
                """
                [phase:clipboard_swap_failed] operationId=\(operationID, privacy: .public) \
                strategy=\(strategy.name, privacy: .public) \
                restoredItemCount=\(savedItems.count) \
                error=\(error.localizedDescription, privacy: .public)
                """
            )
            throw error
        }
    }

    // MARK: - Pasteboard Save / Restore

    private struct SavedPasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [SavedPasteboardItem] {
        guard let types = pasteboard.types else { return [] }

        return types.compactMap { type in
            guard shouldPreservePasteboardType(type) else {
                Self.logger.debug("Skipping non-restorable pasteboard type: \(type.rawValue, privacy: .public)")
                return nil
            }
            return pasteboard.data(forType: type).map { SavedPasteboardItem(type: type, data: $0) }
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, from items: [SavedPasteboardItem]) {
        pasteboard.clearContents()

        guard !items.isEmpty else { return }

        for item in items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }

    private struct FrontmostApplicationInfo {
        let name: String
        let bundleID: String?

        var description: String {
            "\(name) (\(bundleID ?? "unknown"))"
        }
    }

    private func frontmostApplicationInfo() -> FrontmostApplicationInfo {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return FrontmostApplicationInfo(name: "unknown", bundleID: nil)
        }

        return FrontmostApplicationInfo(
            name: app.localizedName ?? "unknown",
            bundleID: app.bundleIdentifier
        )
    }

    private func shouldPreservePasteboardType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let rawValue = type.rawValue

        if type == Self.concealedType || type == Self.transientType {
            return false
        }

        if rawValue.hasPrefix("dyn.") {
            return false
        }

        if rawValue == NSPasteboard.PasteboardType.fileURL.rawValue {
            return false
        }

        if rawValue.contains("file-url") || rawValue.contains("promised-file") {
            return false
        }

        return true
    }

    // MARK: - Simulate ⌘V

    /// Virtual keycode for "V" key
    private static let vKeyCode: UInt16 = 0x09

    private static func defaultPasteAction() -> @Sendable () throws -> Void {
        return {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
                throw ClipboardSwapError.pasteSimulationFailed
            }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
