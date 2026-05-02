import AVFoundation
import CoreMedia
import Foundation
import os

@MainActor
final class AudioRecorderMac: ObservableObject {
    private struct WarmupSnapshot {
        let deviceID: String?
        let date: Date
    }

    private static let warmupTTL: TimeInterval = 60

    @Published private(set) var isRecording = false

    private let defaults: UserDefaults
    private let microphoneProvider: MicrophoneProviding
    private let logger = Logger(subsystem: "com.gmalonso.dictate-mac", category: "AudioRecorder")
    private var coordinator: AudioCaptureCoordinator?
    private var lastWarmupSnapshot: WarmupSnapshot?
    private var warmupTask: Task<Void, Never>?

    /// The file extension that was actually used by the recorder.
    private(set) var actualFileExtension: String = "m4a"

    // MARK: - Recording Settings

    /// AAC-LC 48kbps — lossy, optimized for fast upload. Sweet spot for speech.
    private static let aacDictationSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 48_000,
        AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
    ]

    private static let meterPCMSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsNonInterleaved: false,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1
    ]

    private static let outputFileType: AVFileType = .m4a

    // MARK: - Init

    init(
        defaults: UserDefaults = .app,
        microphoneProvider: MicrophoneProviding = SystemMicrophoneProvider()
    ) {
        self.defaults = defaults
        self.microphoneProvider = microphoneProvider
    }

    // MARK: - Recording

    func start(enableMetering: Bool = true) -> Bool {
        guard !isRecording else { return false }

        guard let (captureDevice, resolvedSelection) = resolvedCaptureDevice() else {
            logger.error("No capture device available for audio recording")
            return false
        }

        let outputURL = makeRecordingURL(ext: Self.outputFileType.defaultPathExtension)

        do {
            let coordinator = try AudioCaptureCoordinator(
                device: captureDevice,
                outputURL: outputURL,
                outputFileType: Self.outputFileType,
                fileAudioSettings: Self.aacDictationSettings,
                meterAudioSettings: enableMetering ? Self.meterPCMSettings : nil,
                logger: logger
            )

            guard coordinator.start() else {
                try? FileManager.default.removeItem(at: outputURL)
                return false
            }

            self.coordinator = coordinator
            self.actualFileExtension = Self.outputFileType.defaultPathExtension
            self.isRecording = true

            if let requestedDeviceID = resolvedSelection.requestedDeviceID,
               !resolvedSelection.savedSelectionAvailable {
                logger.info(
                    """
                    Preferred microphone unavailable (\(requestedDeviceID, privacy: .public)); \
                    using system default \(captureDevice.localizedName, privacy: .public)
                    """
                )
            }

            logger.info("Recording started using microphone: \(captureDevice.localizedName, privacy: .public)")
            return true
        } catch {
            logger.error("Failed to start capture session: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: outputURL)
            return false
        }
    }

    func stop() async -> URL? {
        guard isRecording, let coordinator else { return nil }
        isRecording = false

        let url = await coordinator.stop()
        self.coordinator = nil
        return url
    }

    func cancel() {
        guard isRecording || coordinator != nil else { return }
        coordinator?.cancel()
        coordinator = nil
        isRecording = false
        logger.info("Recording cancelled")
    }

    func prewarmIfPossible() async {
        guard !isRecording else { return }
        guard let (captureDevice, _) = resolvedCaptureDevice() else { return }

        let deviceID = captureDevice.uniqueID
        if let lastWarmupSnapshot,
           lastWarmupSnapshot.deviceID == deviceID,
           Date().timeIntervalSince(lastWarmupSnapshot.date) < Self.warmupTTL {
            logger.debug("Skipping audio warmup for \(deviceID, privacy: .public) — still warm")
            return
        }

        warmupTask?.cancel()
        let logger = self.logger
        warmupTask = Task {
            await Self.performWarmup(deviceID: deviceID, logger: logger)
        }
        await warmupTask?.value

        guard !Task.isCancelled else { return }
        lastWarmupSnapshot = WarmupSnapshot(deviceID: deviceID, date: Date())
    }

    /// Returns normalized amplitude 0.0-1.0 from the live capture pipeline.
    func getNormalizedAmplitude() -> Float {
        coordinator?.currentAmplitude ?? 0
    }

    // MARK: - Helpers

    private func resolvedCaptureDevice() -> (AVCaptureDevice, ResolvedMicrophoneSelection)? {
        let availableMicrophones = microphoneProvider.availableMicrophones()
        let resolvedSelection = MicrophoneSelectionResolver.resolve(
            savedDeviceID: defaults.string(forKey: MacAppKeys.preferredMicrophoneID),
            availableDevices: availableMicrophones
        )

        guard let captureDevice = microphoneProvider.captureDevice(uniqueID: resolvedSelection.effectiveDeviceID) else {
            return nil
        }

        return (captureDevice, resolvedSelection)
    }

    private func makeRecordingURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dictate_recording_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)")
    }

    private static func performWarmup(deviceID: String?, logger: Logger) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let provider = SystemMicrophoneProvider()
                guard let device = provider.captureDevice(uniqueID: deviceID) else {
                    logger.debug("Audio warmup skipped — no capture device available")
                    continuation.resume()
                    return
                }

                let session = AVCaptureSession()
                let output = AVCaptureAudioDataOutput()
                var input: AVCaptureDeviceInput?

                do {
                    let deviceInput = try AVCaptureDeviceInput(device: device)
                    input = deviceInput

                    session.beginConfiguration()
                    if session.canAddInput(deviceInput) {
                        session.addInput(deviceInput)
                    }
                    if session.canAddOutput(output) {
                        session.addOutput(output)
                    }
                    session.commitConfiguration()

                    logger.debug("Audio warmup started for \(device.localizedName, privacy: .public)")
                    session.startRunning()
                    if session.isRunning {
                        usleep(150_000)
                    }
                } catch {
                    logger.debug("Audio warmup failed: \(error.localizedDescription, privacy: .public)")
                }

                if session.outputs.contains(output) {
                    session.removeOutput(output)
                }
                if let input {
                    session.removeInput(input)
                }
                if session.isRunning {
                    session.stopRunning()
                }

                logger.debug("Audio warmup finished for \(device.localizedName, privacy: .public)")
                continuation.resume()
            }
        }
    }
}

private final class AudioCaptureCoordinator: NSObject, @unchecked Sendable {

    /// Passthrough PCM format used for the data output when no metering settings are provided.
    private static let defaultPCMSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsNonInterleaved: false,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1
    ]

    private let device: AVCaptureDevice
    private let outputURL: URL
    private let outputFileType: AVFileType
    private let fileAudioSettings: [String: Any]
    private let meterAudioSettings: [String: Any]?
    private let logger: Logger

    private let session = AVCaptureSession()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.gmalonso.dictate-mac.audio-capture")
    private let stateLock = NSLock()
    private let amplitudeLock = NSLock()

    private var input: AVCaptureDeviceInput?
    private var latestAmplitude: Float = 0

    // AVAssetWriter state — isWriting protected by stateLock, sessionStarted accessed only on sessionQueue
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var isWriting = false
    private var sessionStarted = false

    var currentAmplitude: Float {
        amplitudeLock.withLock { latestAmplitude }
    }

    init(
        device: AVCaptureDevice,
        outputURL: URL,
        outputFileType: AVFileType,
        fileAudioSettings: [String: Any],
        meterAudioSettings: [String: Any]?,
        logger: Logger
    ) throws {
        self.device = device
        self.outputURL = outputURL
        self.outputFileType = outputFileType
        self.fileAudioSettings = fileAudioSettings
        self.meterAudioSettings = meterAudioSettings
        self.logger = logger
        super.init()
        try configureSession()
    }

    func start() -> Bool {
        sessionQueue.sync {
            do {
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
                let writerInput = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: fileAudioSettings
                )
                writerInput.expectsMediaDataInRealTime = true
                writer.add(writerInput)

                session.startRunning()
                guard session.isRunning else {
                    logger.error("Capture session failed to start running")
                    return false
                }

                guard writer.startWriting() else {
                    logger.error("AVAssetWriter failed to start writing: \(writer.error?.localizedDescription ?? "unknown", privacy: .public)")
                    session.stopRunning()
                    return false
                }

                self.assetWriter = writer
                self.assetWriterInput = writerInput
                stateLock.withLock { isWriting = true }
                return true
            } catch {
                logger.error("Failed to create AVAssetWriter: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    func stop() async -> URL? {
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard let writer = assetWriter,
                      let writerInput = assetWriterInput,
                      writer.status == .writing else {
                    teardownSession()
                    resetWriterState()
                    continuation.resume(returning: nil)
                    return
                }

                // Flip the flag only after the queue has drained earlier sample
                // callbacks, otherwise the tail of the recording gets dropped.
                stateLock.withLock { isWriting = false }
                writerInput.markAsFinished()

                // Use nonisolated(unsafe) to suppress Sendable warning —
                // AVAssetWriter is not Sendable but access is serialized
                // through sessionQueue.
                nonisolated(unsafe) let writerRef = writer
                Task {
                    await writerRef.finishWriting()

                    let finalStatus = writerRef.status
                    let finalError = writerRef.error

                    self.sessionQueue.async {
                        self.teardownSession()

                        let result = self.finishRecording(
                            outputFileURL: self.outputURL,
                            error: finalStatus == .completed ? nil : finalError
                        )

                        self.resetWriterState()
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }

    func cancel() {
        stateLock.withLock { isWriting = false }

        sessionQueue.async { [self] in
            if let writer = assetWriter, writer.status == .writing {
                writer.cancelWriting()
            }
            resetWriterState()
            teardownSession()
            try? FileManager.default.removeItem(at: outputURL)
        }

        amplitudeLock.withLock { latestAmplitude = 0 }
    }

    deinit {
        // AVCaptureSession.dealloc → CMIOGraph::DoStop does dispatch_sync on
        // CoreMediaIO's "File output" queue. If the coordinator is deallocated
        // ON that queue, the dispatch_sync deadlocks. Move session teardown and
        // deallocation to a global queue so it is always safe regardless of
        // which thread drops the last reference.
        let session = self.session
        let dataOutput = self.audioDataOutput
        let input = self.input
        let writer = self.assetWriter
        DispatchQueue.global(qos: .utility).async {
            if let writer, writer.status == .writing {
                writer.cancelWriting()
            }
            for output in session.outputs { session.removeOutput(output) }
            if let input { session.removeInput(input) }
            if session.isRunning { session.stopRunning() }
            withExtendedLifetime((session, dataOutput, input, writer)) {}
        }
    }

    private func configureSession() throws {
        let input = try AVCaptureDeviceInput(device: device)
        self.input = input

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input) else {
            throw AudioCaptureCoordinatorError.unableToAddInput(device.localizedName)
        }
        session.addInput(input)

        guard session.canAddOutput(audioDataOutput) else {
            throw AudioCaptureCoordinatorError.unableToAddDataOutput
        }

        audioDataOutput.audioSettings = meterAudioSettings ?? Self.defaultPCMSettings
        audioDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        session.addOutput(audioDataOutput)
    }

    /// Resets AVAssetWriter state. Must be called on sessionQueue.
    private func resetWriterState() {
        assetWriter = nil
        assetWriterInput = nil
        sessionStarted = false
    }

    private func teardownSession() {
        audioDataOutput.setSampleBufferDelegate(nil, queue: nil)
        // Remove outputs and inputs before stopping to cancel pending internal
        // AVCapture callbacks (e.g. format-listener blocks) that would otherwise
        // access freed CMIO graph objects → use-after-free / PAC trap.
        for output in session.outputs {
            session.removeOutput(output)
        }
        if let input {
            session.removeInput(input)
        }
        if session.isRunning {
            session.stopRunning()
        }
        amplitudeLock.withLock {
            latestAmplitude = 0
        }
    }

    private func finishRecording(outputFileURL: URL, error: Error?) -> URL? {
        if let error {
            logger.warning("Audio recording finished with error: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: outputFileURL)
            return nil
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? UInt64) ?? 0
        guard fileSize > 100 else {
            logger.warning("Recording file too small after capture finalization: \(fileSize)")
            try? FileManager.default.removeItem(at: outputFileURL)
            return nil
        }

        logger.info("""
            Recording stopped: \(outputFileURL.lastPathComponent, privacy: .public) \
            (\(fileSize) bytes) using \(self.device.localizedName, privacy: .public)
            """)
        return outputFileURL
    }

    private func setAmplitude(_ amplitude: Float) {
        amplitudeLock.withLock {
            latestAmplitude = amplitude
        }
    }

    private static func normalizedAmplitude(from sampleBuffer: CMSampleBuffer) -> Float {
        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
        )
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else { return 0 }

        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        var accumulatedMeanSquare: Float = 0
        var processedBufferCount = 0

        for buffer in buffers {
            guard let mData = buffer.mData else { continue }
            let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            guard sampleCount > 0 else { continue }

            let samples = UnsafeBufferPointer(
                start: mData.assumingMemoryBound(to: Float.self),
                count: sampleCount
            )

            let meanSquare = samples.reduce(Float.zero) { partialResult, sample in
                partialResult + (sample * sample)
            } / Float(sampleCount)

            accumulatedMeanSquare += meanSquare
            processedBufferCount += 1
        }

        guard processedBufferCount > 0 else { return 0 }
        let rms = sqrt(accumulatedMeanSquare / Float(processedBufferCount))
        return min(max(rms * 2.0, 0), 1)
    }
}

extension AudioCaptureCoordinator: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 1. Metering (only when meter settings were provided)
        if meterAudioSettings != nil {
            setAmplitude(Self.normalizedAmplitude(from: sampleBuffer))
        }

        // 2. Writing
        let writing = stateLock.withLock { isWriting }
        guard writing,
              let writer = assetWriter,
              let writerInput = assetWriterInput,
              writer.status == .writing else { return }

        // First sample: start session with presentation timestamp
        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        // Append
        if writerInput.isReadyForMoreMediaData {
            if !writerInput.append(sampleBuffer) {
                logger.warning("AVAssetWriterInput.append failed, writer status: \(writer.status.rawValue)")
                if writer.status == .failed {
                    stateLock.withLock { isWriting = false }
                }
            }
        }
    }
}

private enum AudioCaptureCoordinatorError: LocalizedError {
    case unableToAddInput(String)
    case unableToAddDataOutput

    var errorDescription: String? {
        switch self {
        case .unableToAddInput(let deviceName):
            return "Unable to add audio input for \(deviceName)"
        case .unableToAddDataOutput:
            return "Unable to add audio data output"
        }
    }
}

private extension AVFileType {
    var defaultPathExtension: String {
        switch self {
        case .m4a:
            return "m4a"
        default:
            return rawValue
        }
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
