import Cocoa
import SwiftUI

enum HotkeySettingViewStyle {
    case expanded
    case compactRow
}

struct HotkeySettingView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var isCapturing = false
    @State private var validationMessage: String?
    @State private var keyMonitor: Any?

    let style: HotkeySettingViewStyle
    let kind: HotkeyManager.HotkeyKind

    init(style: HotkeySettingViewStyle = .expanded, kind: HotkeyManager.HotkeyKind = .dictation) {
        self.style = style
        self.kind = kind
    }

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let rowFont = SettingsComponents.rowFont
    private let helperFont = SettingsComponents.helperFont

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch style {
            case .expanded:
                expandedContent
            case .compactRow:
                compactRowContent
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(helperFont)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: isCapturing) { _, capturing in
            if capturing {
                installKeyCapture()
            } else {
                removeKeyCapture()
            }
        }
        .onDisappear {
            isCapturing = false
            validationMessage = nil
            removeKeyCapture()
        }
    }

    // MARK: - Subviews

    private var expandedContent: some View {
        Group {
            HStack {
                Text(String(localized: "Atalho atual:"))
                    .foregroundStyle(.secondary)

                Text(formattedHotkey)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            if isCapturing {
                capturingView
            } else {
                buttonRow
            }
        }
    }

    private var compactRowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(rowFont)

            Spacer()

            Button {
                startCapturing()
            } label: {
                HStack(spacing: 8) {
                    if isCapturing {
                        ProgressView()
                            .controlSize(.small)
                        Text(String(localized: "Pressione..."))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    } else {
                        Text(formattedHotkey)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(isCapturing ? accentColor : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(isCapturing ? 0.12 : 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help(String(localized: "Clique para gravar uma nova hotkey"))
        }
    }

    private var capturingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(String(localized: "Pressione a nova combinação..."))
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 12) {
            Button(String(localized: "Gravar nova hotkey")) {
                startCapturing()
            }

            Button(restoreDefaultTitle) {
                restoreDefaultHotkey()
            }
        }
    }

    private func startCapturing() {
        validationMessage = nil
        isCapturing = true
    }

    private func restoreDefaultHotkey() {
        validationMessage = nil
        let defaultKeyCode: UInt16
        let defaultModifiers: CGEventFlags
        switch kind {
        case .dictation:
            defaultKeyCode = HotkeyManager.defaultKeyCode
            defaultModifiers = HotkeyManager.defaultModifiers
        case .translation:
            defaultKeyCode = HotkeyManager.defaultTranslationKeyCode
            defaultModifiers = HotkeyManager.defaultTranslationModifiers
        case .pasteLast:
            defaultKeyCode = HotkeyManager.defaultPasteLastKeyCode
            defaultModifiers = HotkeyManager.defaultPasteLastModifiers
        }
        let updated = hotkeyManager.updateHotkey(
            kind: kind,
            keyCode: defaultKeyCode,
            modifiers: defaultModifiers
        )
        if !updated {
            validationMessage = String(localized: "Este atalho já está em uso.")
        }
    }

    // MARK: - Key Capture

    private func installKeyCapture() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels capture
            if event.keyCode == 53 {
                isCapturing = false
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = !modifiers.intersection([.option, .control, .command, .shift]).isEmpty

            if hasModifier {
                let cgFlags = nsFlagsToCGEventFlags(modifiers)
                if hotkeyManager.updateHotkey(kind: kind, keyCode: UInt16(event.keyCode), modifiers: cgFlags) {
                    validationMessage = nil
                } else {
                    validationMessage = String(localized: "Este atalho já está em uso.")
                }
                isCapturing = false
            } else {
                validationMessage = String(localized: "A combinação precisa incluir pelo menos um modificador (⌥, ⌃, ⌘ ou ⇧).")
                isCapturing = false
            }

            return nil // Suppress the captured key
        }
    }

    private func removeKeyCapture() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Formatting

    private var formattedHotkey: String {
        hotkeyManager.formattedHotkey(for: kind)
    }

    private var title: String {
        switch kind {
        case .dictation: String(localized: "Tecla de atalho")
        case .translation: String(localized: "Tecla de tradução")
        case .pasteLast: String(localized: "Tecla de colar última")
        }
    }

    private var restoreDefaultTitle: String {
        switch kind {
        case .dictation: String(localized: "Restaurar padrão (⌃⇧D)")
        case .translation: String(localized: "Restaurar padrão (⌃⇧F)")
        case .pasteLast: String(localized: "Restaurar padrão (⌃⇧V)")
        }
    }

    private func nsFlagsToCGEventFlags(_ flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var cgFlags = CGEventFlags()
        if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }
        if flags.contains(.shift) { cgFlags.insert(.maskShift) }
        return cgFlags
    }
}

#Preview {
    HotkeySettingView()
        .padding()
        .frame(width: 400)
}
