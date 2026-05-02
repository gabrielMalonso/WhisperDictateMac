import AVFoundation
import Foundation
import os

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false

    private let logger = Logger(subsystem: "com.gmalonso.whisper-dictate-mac", category: "AudioRecorder")
    private var coordinator: AudioCaptureCoordinator?

    func start() throws {
        guard !isRecording else { return }
        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw AudioRecorderError.noInputDevice
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-dictate-\(UUID().uuidString).wav")

        let coordinator = try AudioCaptureCoordinator(device: device, outputURL: outputURL, logger: logger)
        guard coordinator.start() else {
            throw AudioRecorderError.startFailed
        }

        self.coordinator = coordinator
        isRecording = true
    }

    func stop() async throws -> URL {
        guard isRecording, let coordinator else {
            throw AudioRecorderError.notRecording
        }

        isRecording = false
        self.coordinator = nil

        guard let url = await coordinator.stop() else {
            throw AudioRecorderError.outputMissing
        }

        return url
    }

    func cancel() {
        coordinator?.cancel()
        coordinator = nil
        isRecording = false
    }

    var currentAmplitude: Float {
        coordinator?.currentAmplitude ?? 0
    }
}

enum AudioRecorderError: LocalizedError {
    case noInputDevice
    case startFailed
    case notRecording
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "Nenhum microfone encontrado."
        case .startFailed:
            return "Nao foi possivel iniciar a gravacao."
        case .notRecording:
            return "Nao ha gravacao ativa."
        case .outputMissing:
            return "O arquivo de audio nao foi gerado."
        }
    }
}

private final class AudioCaptureCoordinator: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let outputURL: URL
    private let logger: Logger
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.gmalonso.whisper-dictate-mac.audio")
    private let stateLock = NSLock()
    private let amplitudeLock = NSLock()

    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var writing = false
    private var amplitude: Float = 0

    var currentAmplitude: Float {
        amplitudeLock.withLock { amplitude }
    }

    init(device: AVCaptureDevice, outputURL: URL, logger: Logger) throws {
        self.outputURL = outputURL
        self.logger = logger
        super.init()

        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        if session.canAddInput(input) {
            session.addInput(input)
        }
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    func start() -> Bool {
        queue.sync {
            do {
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
                input.expectsMediaDataInRealTime = true

                guard writer.canAdd(input) else { return false }
                writer.add(input)

                session.startRunning()
                guard session.isRunning, writer.startWriting() else {
                    session.stopRunning()
                    return false
                }

                self.writer = writer
                self.writerInput = input
                stateLock.withLock { writing = true }
                return true
            } catch {
                logger.error("Audio writer failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }

    func stop() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                self.finish(removeFile: false, continuation: continuation)
            }
        }
    }

    func cancel() {
        queue.async {
            self.finish(removeFile: true, continuation: nil)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        updateAmplitude(sampleBuffer)

        guard stateLock.withLock({ writing }),
              let writer,
              let writerInput,
              writerInput.isReadyForMoreMediaData else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        writerInput.append(sampleBuffer)
    }

    private func finish(removeFile: Bool, continuation: CheckedContinuation<URL?, Never>?) {
        let wasWriting = stateLock.withLock {
            let oldValue = writing
            writing = false
            return oldValue
        }

        if session.isRunning {
            session.stopRunning()
        }

        guard wasWriting, let writerInput, let writer else {
            if removeFile {
                try? FileManager.default.removeItem(at: outputURL)
            }
            continuation?.resume(returning: nil)
            return
        }

        writerInput.markAsFinished()
        writer.finishWriting {
            if removeFile {
                try? FileManager.default.removeItem(at: self.outputURL)
                continuation?.resume(returning: nil)
            } else {
                continuation?.resume(returning: writer.status == .completed ? self.outputURL : nil)
            }
        }
    }

    private func updateAmplitude(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        ) == noErr, let dataPointer else {
            return
        }

        let samples = dataPointer.withMemoryRebound(to: Int16.self, capacity: length / MemoryLayout<Int16>.size) {
            UnsafeBufferPointer(start: $0, count: length / MemoryLayout<Int16>.size)
        }
        guard !samples.isEmpty else { return }

        let maxSample = samples.lazy.map { abs(Float($0)) / Float(Int16.max) }.max() ?? 0
        amplitudeLock.withLock {
            amplitude = min(1, maxSample * 6)
        }
    }
}
