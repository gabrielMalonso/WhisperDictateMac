import AVFoundation
import Foundation

struct MicrophoneDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isSystemDefault: Bool
}

struct ResolvedMicrophoneSelection: Equatable {
    let requestedDeviceID: String?
    let effectiveDeviceID: String?
    let savedSelectionAvailable: Bool

    var usesSystemDefault: Bool {
        effectiveDeviceID == nil
    }
}

protocol MicrophoneProviding {
    func availableMicrophones() -> [MicrophoneDevice]
    func captureDevice(uniqueID: String?) -> AVCaptureDevice?
}

struct SystemMicrophoneProvider: MicrophoneProviding {
    func availableMicrophones() -> [MicrophoneDevice] {
        let systemDefaultID = AVCaptureDevice.default(for: .audio)?.uniqueID
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )

        return discoverySession.devices
            .map { device in
                MicrophoneDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isSystemDefault: device.uniqueID == systemDefaultID
                )
            }
            .sorted { lhs, rhs in
                if lhs.id == systemDefaultID, rhs.id != systemDefaultID {
                    return true
                }
                if rhs.id == systemDefaultID, lhs.id != systemDefaultID {
                    return false
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func captureDevice(uniqueID: String?) -> AVCaptureDevice? {
        guard let uniqueID,
              !uniqueID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AVCaptureDevice.default(for: .audio)
        }
        return AVCaptureDevice(uniqueID: uniqueID) ?? AVCaptureDevice.default(for: .audio)
    }
}

enum MicrophoneSelectionResolver {
    static func normalizedSavedDeviceID(_ rawValue: String?) -> String? {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    static func resolve(
        savedDeviceID rawValue: String?,
        availableDevices: [MicrophoneDevice]
    ) -> ResolvedMicrophoneSelection {
        let requestedDeviceID = normalizedSavedDeviceID(rawValue)
        guard let requestedDeviceID else {
            return ResolvedMicrophoneSelection(
                requestedDeviceID: nil,
                effectiveDeviceID: nil,
                savedSelectionAvailable: true
            )
        }

        guard availableDevices.contains(where: { $0.id == requestedDeviceID }) else {
            return ResolvedMicrophoneSelection(
                requestedDeviceID: requestedDeviceID,
                effectiveDeviceID: nil,
                savedSelectionAvailable: false
            )
        }

        return ResolvedMicrophoneSelection(
            requestedDeviceID: requestedDeviceID,
            effectiveDeviceID: requestedDeviceID,
            savedSelectionAvailable: true
        )
    }
}
