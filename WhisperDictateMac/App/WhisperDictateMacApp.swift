import SwiftUI

@main
struct WhisperDictateMacApp: App {
    @StateObject private var controller = DictationController()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Window("Whisper Dictate", id: "main") {
            ContentView()
                .environmentObject(controller)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    controller.startHotkey()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 780, height: 560)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Text(controller.statusText)
                .font(.headline)

            Divider()

            Button("Abrir") {
                NSApplication.shared.setActivationPolicy(.regular)
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            Button(controller.primaryActionTitle) {
                Task { await controller.toggleDictation() }
            }
            .disabled(controller.state == .transcribing)

            if controller.hasLastTranscript {
                Button("Colar ultima transcricao") {
                    Task { await controller.pasteLastTranscript() }
                }
            }

            Divider()

            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image("MenuBarIcon")
        }
    }
}

