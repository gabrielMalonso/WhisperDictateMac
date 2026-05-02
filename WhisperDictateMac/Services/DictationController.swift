import Foundation
import SwiftUI

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
}

@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var currentAmplitude: Float = 0
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var lastTranscript: String?
    @Published private(set) var errorMessage: String?

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let paster = ClipboardPaster()
    private let hotkey = GlobalHotkey()
    private let defaults = AppSettings.defaults

    private var recordingStartedAt: Date?
    private var amplitudeTimer: Timer?
    private var elapsedTimer: Timer?

    init() {
        AppSettings.registerDefaults()
    }

    var hasLastTranscript: Bool {
        !(lastTranscript ?? "").isEmpty
    }

    var primaryActionTitle: String {
        switch state {
        case .idle:
            return "Gravar"
        case .recording:
            return "Parar"
        case .transcribing:
            return "Transcrevendo..."
        }
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Pronto"
        case .recording:
            return "Gravando"
        case .transcribing:
            return "Transcrevendo com Whisper"
        }
    }

    var statusIcon: String {
        switch state {
        case .idle:
            return "checkmark.circle.fill"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        }
    }

    var elapsedText: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startHotkey() {
        hotkey.register { [weak self] in
            Task { @MainActor in
                await self?.toggleDictation()
            }
        }
    }

    func toggleDictation() async {
        switch state {
        case .idle:
            await startRecording()
        case .recording:
            await stopAndTranscribe()
        case .transcribing:
            NSSound.beep()
        }
    }

    func pasteLastTranscript() async {
        guard let transcript = lastTranscript, !transcript.isEmpty else {
            NSSound.beep()
            return
        }

        do {
            try await paster.paste(transcript, restoreClipboard: defaults.bool(forKey: AppSettings.restoreClipboardKey))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startRecording() async {
        errorMessage = nil

        let dependencies = DependencyChecker.check()
        guard dependencies.isReady else {
            errorMessage = "Configure antes de gravar: \(dependencies.missingItems.joined(separator: ", "))."
            return
        }

        guard await PermissionManager.requestMicrophoneAccess() else {
            errorMessage = "Permita o microfone para gravar."
            return
        }

        guard PermissionManager.requestAccessibilityAccess() else {
            PermissionManager.openAccessibilitySettings()
            errorMessage = "Acessibilidade ainda nao foi reconhecida. Se ja estiver marcada, remova o app da lista e adicione este build de novo."
            return
        }

        do {
            try recorder.start()
            state = .recording
            recordingStartedAt = Date()
            elapsedSeconds = 0
            currentAmplitude = 0
            startTimers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndTranscribe() async {
        stopTimers()

        guard let startedAt = recordingStartedAt, Date().timeIntervalSince(startedAt) >= 0.6 else {
            recorder.cancel()
            resetRecordingState()
            state = .idle
            return
        }

        state = .transcribing
        resetRecordingState()

        do {
            let audioURL = try await recorder.stop()
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let transcript = try await transcriber.transcribe(audioURL: audioURL)
            lastTranscript = transcript

            if !transcript.isEmpty {
                try await paster.paste(transcript, restoreClipboard: defaults.bool(forKey: AppSettings.restoreClipboardKey))
            }

            state = .idle
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
    }

    private func startTimers() {
        amplitudeTimer?.invalidate()
        elapsedTimer?.invalidate()

        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentAmplitude = self?.recorder.currentAmplitude ?? 0
            }
        }

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.recordingStartedAt else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
            }
        }
    }

    private func stopTimers() {
        amplitudeTimer?.invalidate()
        elapsedTimer?.invalidate()
        amplitudeTimer = nil
        elapsedTimer = nil
    }

    private func resetRecordingState() {
        recordingStartedAt = nil
        currentAmplitude = 0
        elapsedSeconds = 0
    }
}
