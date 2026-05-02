import AVFoundation
import Cocoa
import Combine
import os

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published private(set) var microphoneGranted: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false

    var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    var pendingCount: Int {
        [microphoneGranted, accessibilityGranted].filter { !$0 }.count
    }

    private var pollingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "PermissionManager")

    private init() {
        refreshMicrophoneStatus()
        refreshAccessibilityStatus()
        logger.info("PermissionManager init — mic: \(self.microphoneGranted), accessibility: \(self.accessibilityGranted)")
        logger.info("AXIsProcessTrusted() = \(AXIsProcessTrusted())")
        logger.info("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        if let bundlePath = Bundle.main.executablePath {
            logger.info("Executable: \(bundlePath)")
        }
    }

    // MARK: - Microphone

    func requestMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.microphoneGranted = granted
                }
            }
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    // MARK: - Accessibility

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()
        logger.info("startPolling() called")
        pollingTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                tick += 1
                self?.refreshAccessibilityStatus()
                self?.refreshMicrophoneStatus()
                if tick <= 5 || tick % 10 == 0 {
                    self?.logger.info("Poll #\(tick) — AXIsProcessTrusted()=\(AXIsProcessTrusted()), mic=\(self?.microphoneGranted ?? false), accessibility=\(self?.accessibilityGranted ?? false)")
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Private

    private func refreshMicrophoneStatus() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        if trusted != accessibilityGranted {
            logger.info("Accessibility status changed: \(trusted)")
        }
        accessibilityGranted = trusted
    }

}
