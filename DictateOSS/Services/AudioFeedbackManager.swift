import AppKit

final class AudioFeedbackManager {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .app) {
        self.defaults = defaults
        defaults.register(defaults: [
            MacAppKeys.soundFeedbackEnabled: true,
            MacAppKeys.soundFeedbackVolume: 0.7
        ])
    }

    var isEnabled: Bool {
        defaults.bool(forKey: MacAppKeys.soundFeedbackEnabled)
    }

    var volume: Float {
        Float(defaults.double(forKey: MacAppKeys.soundFeedbackVolume))
    }

    func playStart() {
        play("Tink")
    }

    func playStop() {
        play("Morse")
    }

    func playCancel() {
        play("Pop")
    }

    func playSuccess() {
        play("Glass")
    }

    func playError() {
        play("Basso")
    }

    func playTest() {
        play("Tink", requireEnabled: false)
    }

    private func play(_ name: String, requireEnabled: Bool = true) {
        guard !requireEnabled || isEnabled else { return }
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.stop()
        sound.volume = volume
        sound.play()
    }
}
