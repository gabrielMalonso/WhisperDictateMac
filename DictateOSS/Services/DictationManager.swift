import AppKit
import Combine
import Foundation
import os
import SwiftData

enum TranscriptionError: Error, LocalizedError {
    case transcriptionFailed(message: String)
    case audioFileNotFound
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let message):
            return message
        case .audioFileNotFound:
            return String(localized: "Arquivo de áudio não encontrado.")
        case .storageUnavailable:
            return String(localized: "Armazenamento local indisponível.")
        }
    }
}

enum DictationState: Equatable {
    case idle
    case arming
    case recording
    case transcribing
}

enum RecordingOverlayBannerStyle: Equatable {
    case info
    case warning
    case error
}

struct RecordingOverlayBanner: Equatable {
    let icon: String
    let message: String
    let style: RecordingOverlayBannerStyle
}

@MainActor
final class DictationManager: ObservableObject {
    static let shared = DictationManager()

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var currentAmplitude: Float = 0
    @Published private(set) var elapsedSeconds: Int = 0
    @Published var lastError: TranscriptionError?
    @Published private(set) var overlayBanner: RecordingOverlayBanner?
    @Published private(set) var lastTranscribedText: String?
    @Published private(set) var hasLastTranscription = false

    private let audioRecorder: AudioRecorderMac
    private let clipboardSwapManager: ClipboardSwapManager
    private let permissionManager: PermissionManager
    private let errorNotificationService: ErrorNotificationService
    private let audioFeedback = AudioFeedbackManager()
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "DictationManager")

    var modelContext: ModelContext?

    private var timeoutTimer: Timer?
    private var amplitudeTimer: Timer?
    private var elapsedTimer: Timer?
    private var recordingStartTime: Date?
    private var transcriptionGeneration = 0
    private var activeTranscriptionClientId: UUID?
    private var lastTranscriptionSourceDate: Date?
    private var recordingSessionID: UUID?
    private var toggleRequestCounter = 0
    private var activeRecordingTranslationRequested = false
    private var overlayBannerDismissTask: Task<Void, Never>?

    private init() {
        self.audioRecorder = AudioRecorderMac()
        self.clipboardSwapManager = ClipboardSwapManager()
        self.permissionManager = .shared
        self.errorNotificationService = .shared
        self.defaults = .app
    }

    func toggle(translationRequested: Bool = false) async {
        toggleRequestCounter += 1
        let triggerId = toggleRequestCounter
        logger.info("[phase:toggle_received] triggerId=\(triggerId) state=\(String(describing: self.state), privacy: .public)")

        switch state {
        case .idle:
            await startRecording(triggerId: triggerId, translationRequested: translationRequested)
        case .arming:
            NSSound.beep()
        case .recording:
            await stopAndTranscribe(triggerId: triggerId)
        case .transcribing:
            NSSound.beep()
        }
    }

    func pasteLastTranscription() async {
        guard let text = lastTranscribedText, !text.isEmpty, state == .idle else {
            NSSound.beep()
            return
        }

        do {
            try await pasteWithAutoSpacing(text)
        } catch {
            logger.error("Failed to re-paste: \(error.localizedDescription)")
            errorNotificationService.showError(
                title: String(localized: "Falha ao Colar"),
                message: String(localized: "Não foi possível colar a última transcrição. O texto foi copiado para a área de transferência.")
            )
        }
    }

    func cancel() {
        switch state {
        case .idle:
            return
        case .arming, .recording:
            audioRecorder.cancel()
            stopAllTimers()
            resetRecordingState()
            state = .idle
            audioFeedback.playCancel()
            clearOverlayBanner()
        case .transcribing:
            let clientId = activeTranscriptionClientId
            transcriptionGeneration += 1
            activeTranscriptionClientId = nil
            state = .idle
            audioFeedback.playCancel()
            clearOverlayBanner()
            Task {
                await TranscriptionPipeline.requestCancellation(for: clientId)
            }
        }
    }

    private func startRecording(triggerId: Int, translationRequested: Bool) async {
        guard permissionManager.microphoneGranted else {
            let banner = RecordingOverlayBanner(
                icon: "mic.slash.fill",
                message: String(localized: "Microfone sem permissão."),
                style: .error
            )
            flashOverlayBanner(banner)
            errorNotificationService.showPermissionRequired(String(localized: "Microfone"))
            return
        }

        guard permissionManager.accessibilityGranted else {
            let banner = RecordingOverlayBanner(
                icon: "hand.raised.fill",
                message: String(localized: "Acessibilidade sem permissão."),
                style: .error
            )
            flashOverlayBanner(banner)
            errorNotificationService.showPermissionRequired(String(localized: "Acessibilidade"))
            return
        }

        prepareForRecordingStart()
        let sessionID = UUID()
        recordingSessionID = sessionID
        activeRecordingTranslationRequested = translationRequested
        state = .arming

        audioFeedback.playStart()
        let started = audioRecorder.start(enableMetering: true)
        guard started else {
            resetRecordingState()
            state = .idle
            let banner = RecordingOverlayBanner(
                icon: "exclamationmark.circle.fill",
                message: String(localized: "Não foi possível iniciar a gravação."),
                style: .error
            )
            flashOverlayBanner(banner)
            errorNotificationService.showError(
                title: String(localized: "Falha na Gravação"),
                message: String(localized: "Não foi possível iniciar a gravação. Verifique a permissão do microfone.")
            )
            return
        }

        state = .recording
        recordingStartTime = Date()
        elapsedSeconds = 0
        currentAmplitude = 0
        startTimers()
        logger.info("[phase:recording_active] triggerId=\(triggerId) sessionId=\(sessionID.uuidString, privacy: .public)")
    }

    private func stopAndTranscribe(triggerId: Int = 0) async {
        guard state == .recording else { return }

        stopAllTimers()
        let audioDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        if audioDuration < 1.0 {
            audioRecorder.cancel()
            resetRecordingState()
            state = .idle
            audioFeedback.playCancel()
            clearOverlayBanner()
            return
        }

        transcriptionGeneration += 1
        let expectedGeneration = transcriptionGeneration
        let clientId = UUID()
        activeTranscriptionClientId = clientId
        let translationRequested = activeRecordingTranslationRequested
        state = .transcribing
        audioFeedback.playStop()
        resetRecordingState()

        guard let audioURL = await audioRecorder.stop() else {
            state = .idle
            activeTranscriptionClientId = nil
            let error = TranscriptionError.audioFileNotFound
            lastError = error
            flashOverlayBanner(Self.overlayBanner(for: error))
            errorNotificationService.showError(
                title: String(localized: "Erro na Gravação"),
                message: error.localizedDescription
            )
            return
        }

        logger.info("[phase:recording_stopped] triggerId=\(triggerId) audioDuration=\(audioDuration)")
        await performTranscription(
            audioURL: audioURL,
            audioDuration: audioDuration,
            translationRequested: translationRequested,
            generation: expectedGeneration,
            clientId: clientId
        )
    }

    private func performTranscription(
        audioURL: URL,
        audioDuration: TimeInterval,
        translationRequested: Bool,
        generation: Int,
        clientId: UUID
    ) async {
        guard let modelContext else {
            state = .idle
            activeTranscriptionClientId = nil
            let error = TranscriptionError.storageUnavailable
            lastError = error
            flashOverlayBanner(Self.overlayBanner(for: error))
            deleteAudioFile(at: audioURL)
            return
        }

        let result = await TranscriptionPipeline.transcribe(
            audioURL: audioURL,
            audioDuration: audioDuration,
            clientId: clientId,
            persistResult: false,
            translationRequested: translationRequested,
            defaults: defaults,
            modelContext: modelContext
        )

        guard generation == transcriptionGeneration else {
            if activeTranscriptionClientId == clientId {
                activeTranscriptionClientId = nil
            }
            deleteAudioFile(at: audioURL)
            return
        }
        activeTranscriptionClientId = nil

        switch result {
        case .success(let pipelineResult):
            let text = pipelineResult.text
            TranscriptionPipeline.persistRecord(
                text: text,
                audioDuration: audioDuration,
                language: pipelineResult.persistedLanguage,
                clientId: pipelineResult.clientId,
                modelContext: modelContext
            )
            storeLatestTranscription(text)
            lastError = nil
            flashOverlayBanner(Self.overlayBanner(for: pipelineResult.fallbackReason))
            state = .idle
            audioFeedback.playSuccess()
            updateCumulativeStats(wordCount: pipelineResult.wordCount, audioDuration: audioDuration)
            deleteAudioFile(at: audioURL)

            do {
                try await pasteWithAutoSpacing(text)
            } catch {
                logger.error("Failed to paste text: \(error.localizedDescription)")
                errorNotificationService.showError(
                    title: String(localized: "Falha ao Colar"),
                    message: String(localized: "A transcrição foi concluída, mas a colagem falhou. O texto foi copiado para a área de transferência.")
                )
            }

        case .failure(.cancelled):
            lastError = nil
            state = .idle
            clearOverlayBanner()
            deleteAudioFile(at: audioURL)

        case .failure(let error):
            let transcriptionError = TranscriptionError.transcriptionFailed(message: error.localizedDescription)
            lastError = transcriptionError
            flashOverlayBanner(Self.overlayBanner(for: transcriptionError))
            state = .idle
            audioFeedback.playError()
            notifyTranscriptionError(transcriptionError)
            deleteAudioFile(at: audioURL)
        }
    }

    func handleSessionTermination() {
        switch state {
        case .idle:
            clearOverlayBanner()
            clearLastTranscription()
        case .arming, .recording:
            audioRecorder.cancel()
            stopAllTimers()
            resetRecordingState()
            state = .idle
            clearOverlayBanner()
            clearLastTranscription()
        case .transcribing:
            let clientId = activeTranscriptionClientId
            transcriptionGeneration += 1
            activeTranscriptionClientId = nil
            state = .idle
            clearOverlayBanner()
            clearLastTranscription()
            Task {
                await TranscriptionPipeline.requestCancellation(for: clientId)
            }
        }
    }

    private func startTimers() {
        let timeout = min(AppConfig.defaultDictationTimeout, AppConfig.maxRecordingDuration)
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                await self.stopAndTranscribe()
            }
        }

        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                self.currentAmplitude = self.audioRecorder.getNormalizedAmplitude()
            }
        }

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                self.elapsedSeconds += 1
            }
        }
    }

    private func stopAllTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func resetRecordingState() {
        currentAmplitude = 0
        elapsedSeconds = 0
        recordingStartTime = nil
        recordingSessionID = nil
        activeRecordingTranslationRequested = false
    }

    private func notifyTranscriptionError(_ error: TranscriptionError) {
        errorNotificationService.showError(
            title: String(localized: "Falha na Transcrição"),
            message: error.localizedDescription
        )
    }

    private func flashOverlayBanner(
        _ banner: RecordingOverlayBanner,
        duration: Duration = .seconds(4)
    ) {
        overlayBannerDismissTask?.cancel()
        overlayBanner = banner
        overlayBannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.overlayBanner = nil
            self?.overlayBannerDismissTask = nil
        }
    }

    private func clearOverlayBanner() {
        overlayBannerDismissTask?.cancel()
        overlayBannerDismissTask = nil
        overlayBanner = nil
    }

    private func pasteWithAutoSpacing(_ rawText: String) async throws {
        let contextBefore = AccessibilityTextReader.characterBeforeCursor()
        let text = PendingInsertionPolicy.textToInsert(rawText: rawText, contextBefore: contextBefore)
        try await clipboardSwapManager.pasteText(text)
    }

    func prewarmAudioCapture() async {
        await audioRecorder.prewarmIfPossible()
    }

    func prepareForRecordingStart() {
        lastError = nil
        clearOverlayBanner()
    }

    func storeLatestTranscription(_ text: String, sourceDate: Date = Date()) {
        lastTranscribedText = text
        lastTranscriptionSourceDate = sourceDate
        hasLastTranscription = !text.isEmpty
    }

    func handleRecoveredTranscription(_ text: String, sourceDate: Date) {
        let didBecomeLatest = shouldReplaceLastTranscription(with: sourceDate)
        if didBecomeLatest {
            storeLatestTranscription(text, sourceDate: sourceDate)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    func clearLastTranscription() {
        lastTranscribedText = nil
        lastTranscriptionSourceDate = nil
        hasLastTranscription = false
    }

    private func shouldReplaceLastTranscription(with sourceDate: Date) -> Bool {
        guard let lastTranscriptionSourceDate else { return true }
        return sourceDate >= lastTranscriptionSourceDate
    }

    private func deleteAudioFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.warning("Failed to delete temp audio file: \(error.localizedDescription)")
        }
    }

    private func updateCumulativeStats(wordCount: Int, audioDuration: TimeInterval) {
        let totalDictations = defaults.integer(forKey: MacAppKeys.localTotalDictations)
        defaults.set(totalDictations + 1, forKey: MacAppKeys.localTotalDictations)

        let totalWords = defaults.integer(forKey: MacAppKeys.localTotalWords)
        defaults.set(totalWords + wordCount, forKey: MacAppKeys.localTotalWords)

        let totalDuration = defaults.double(forKey: MacAppKeys.localTotalDurationSeconds)
        defaults.set(totalDuration + audioDuration, forKey: MacAppKeys.localTotalDurationSeconds)
    }

    static func overlayBanner(
        for fallbackReason: TranscriptionFallbackReason?
    ) -> RecordingOverlayBanner {
        RecordingOverlayBanner(
            icon: "checkmark.circle.fill",
            message: String(localized: "Transcrição local concluída."),
            style: .info
        )
    }

    static func overlayBanner(for error: TranscriptionError) -> RecordingOverlayBanner {
        RecordingOverlayBanner(
            icon: "exclamationmark.circle.fill",
            message: error.localizedDescription,
            style: .error
        )
    }
}
