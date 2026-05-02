import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "DictateOSS")

@main
struct DictateOSS: App {
    @StateObject private var dictationManager = DictationManager.shared
    @Environment(\.openWindow) private var openWindow

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var isMenuBarVisible = true

    private let modelContainer = AppModelContainer.container

    init() {
        // Start as an accessory app (menu bar only, no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Inject modelContext into DictationManager for SwiftData persistence
        let modelContext = ModelContext(modelContainer)
        DictationManager.shared.modelContext = modelContext

        // Connect hotkey to dictation toggle
        HotkeyManager.shared.onHotkeyPressed = {
            Task { @MainActor in
                await DictationManager.shared.toggle()
            }
        }

        HotkeyManager.shared.onTranslationHotkeyPressed = {
            Task { @MainActor in
                guard UserDefaults.app.bool(forKey: MacAppKeys.translationEnabled),
                      FeatureAvailability.canUseTranslation else {
                    NSSound.beep()
                    return
                }
                await DictationManager.shared.toggle(translationRequested: true)
            }
        }

        // Connect ESC to cancel recording
        HotkeyManager.shared.onEscPressed = {
            Task { @MainActor in
                DictationManager.shared.cancel()
            }
        }

        // Let HotkeyManager know when recording is active (to suppress ESC)
        HotkeyManager.shared.isRecordingActive = {
            DictationManager.shared.state != .idle
        }

        // Connect the configurable paste-last hotkey.
        HotkeyManager.shared.onPasteLastPressed = {
            Task { @MainActor in
                await DictationManager.shared.pasteLastTranscription()
            }
        }

        // Start listening for the global hotkey
        HotkeyManager.shared.start()

        // Initialize floating overlay (singleton, self-managing via Combine)
        _ = RecordingOverlayPanelController.shared

        Task { @MainActor in
            guard PermissionManager.shared.microphoneGranted else { return }
            await DictationManager.shared.prewarmAudioCapture()
        }

    }

    var body: some Scene {
        Window("Dictate", id: "main") {
            ContentView()
                .tint((AccentColorOption(rawValue: accentColorRaw) ?? .default).color)
                .onAppear {
                    // Show Dock icon when window is visible
                    NSApplication.shared.setActivationPolicy(.regular)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    guard let window = notification.object as? NSWindow,
                          window.title == "Dictate" || window.identifier?.rawValue == "main" else {
                        return
                    }
                    // Hide Dock icon when main window closes
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)

        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarIcon
        }
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: some View {
        let nsImage = NSImage(named: "MenuBarIcon")!
        nsImage.size = NSSize(width: 18, height: 18)
        nsImage.isTemplate = true
        return Image(nsImage: nsImage)
    }

    // MARK: - Menu Bar Content

    @ViewBuilder
    private var menuBarContent: some View {
        // Status line
        Text(statusText)
            .font(.headline)

        Divider()

        // Open main window
        Button(String(localized: "Abrir Dictate")) {
            openMainWindow()
        }

        // Dictation toggle
        if dictationManager.state == .idle {
            Button(String(localized: "Iniciar Gravação")) {
                Task {
                    await dictationManager.toggle()
                }
            }
        } else if dictationManager.state == .arming {
            Text(String(localized: "Preparando..."))
                .foregroundStyle(.secondary)
        } else if dictationManager.state == .recording {
            Button(String(localized: "Parar Gravação")) {
                Task {
                    await dictationManager.toggle()
                }
            }
        } else {
            Text(String(localized: "Transcrevendo..."))
                .foregroundStyle(.secondary)
        }

        if Self.shouldShowPasteLastMenuItem(
            state: dictationManager.state,
            hasLastTranscription: dictationManager.hasLastTranscription
        ) {
            Button(String(localized: "Colar Última Transcrição")) {
                Task {
                    await dictationManager.pasteLastTranscription()
                }
            }
        }

        // Quit
        Button(String(localized: "Sair")) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Status Text

    private var statusText: String {
        switch dictationManager.state {
        case .idle:
            return String(localized: "Pronto")
        case .arming:
            return String(localized: "Preparando...")
        case .recording:
            let timestamp = formatRecordingTimer(seconds: dictationManager.elapsedSeconds)
            return AppText.recordingStatus(timestamp: timestamp)
        case .transcribing:
            return String(localized: "Transcrevendo...")
        }
    }

    // MARK: - Window Management

    private func openMainWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func shouldShowPasteLastMenuItem(
        state: DictationState,
        hasLastTranscription: Bool
    ) -> Bool {
        state == .idle && hasLastTranscription
    }
}
