import Foundation

enum FeatureGate {
    private static var defaults: UserDefaults { UserDefaults.app }

    // MARK: - Public API

    static var isPro: Bool { true }

    static func canUseDomain(_ domain: TranscriptionDomain) -> Bool {
        canUseDomain(domain, from: defaults)
    }

    static func canUseTone(_ tone: Tone) -> Bool {
        canUseTone(tone, from: defaults)
    }

    static var canUseTranslation: Bool { canUseTranslation(from: defaults) }

    // MARK: - Testable overloads

    static func canUseDomain(_ domain: TranscriptionDomain, from defaults: UserDefaultsProviding) -> Bool {
        true
    }

    static func canUseTone(_ tone: Tone, from defaults: UserDefaultsProviding) -> Bool {
        true
    }

    static func canUseTranslation(from defaults: UserDefaultsProviding) -> Bool {
        false
    }
}
