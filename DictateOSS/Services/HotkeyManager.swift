import Cocoa
import CoreGraphics
import os

final class HotkeyManager: ObservableObject {
    enum HotkeyKind: CaseIterable {
        case dictation
        case translation
        case pasteLast
    }

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Published State

    @Published var currentKeyCode: UInt16
    @Published var currentModifiers: CGEventFlags
    @Published var currentTranslationKeyCode: UInt16
    @Published var currentTranslationModifiers: CGEventFlags
    @Published var currentPasteLastKeyCode: UInt16
    @Published var currentPasteLastModifiers: CGEventFlags

    // MARK: - Callbacks

    var onHotkeyPressed: (() -> Void)?
    var onTranslationHotkeyPressed: (() -> Void)?
    var onEscPressed: (() -> Void)?
    var onPasteLastPressed: (() -> Void)?

    /// Returns `true` when the app is actively recording or transcribing.
    /// Used by the CGEvent tap to suppress the Escape key only while active.
    var isRecordingActive: (() -> Bool)?

    // MARK: - Private

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private let defaults: UserDefaults
    fileprivate let logger = Logger(subsystem: "com.gmalonso.dictate-oss", category: "HotkeyManager")

    /// Indicates whether the CGEvent tap is active (suppresses key events).
    /// When false, falls back to NSEvent global monitor (no suppression).
    private(set) var isEventTapActive: Bool = false

    // MARK: - Defaults

    static let defaultKeyCode: UInt16 = 2 // "D"
    static let defaultModifiers: CGEventFlags = [.maskControl, .maskShift] // ⌃⇧
    static let defaultTranslationKeyCode: UInt16 = 3 // "F"
    static let defaultTranslationModifiers: CGEventFlags = [.maskControl, .maskShift] // ⌃⇧
    static let defaultPasteLastKeyCode: UInt16 = 9 // "V"
    static let defaultPasteLastModifiers: CGEventFlags = [.maskControl, .maskShift] // ⌃⇧

    // MARK: - Init

    init(defaults: UserDefaults = .app) {
        self.defaults = defaults

        // Load saved hotkey or use defaults
        let savedKeyCode = defaults.object(forKey: MacAppKeys.hotkeyKeyCode) as? Int
        let savedModifiers = defaults.object(forKey: MacAppKeys.hotkeyModifiers) as? UInt64
        let savedTranslationKeyCode = defaults.object(forKey: MacAppKeys.translationHotkeyKeyCode) as? Int
        let savedTranslationModifiers = defaults.object(forKey: MacAppKeys.translationHotkeyModifiers) as? UInt64
        let savedPasteLastKeyCode = defaults.object(forKey: MacAppKeys.pasteLastHotkeyKeyCode) as? Int
        let savedPasteLastModifiers = defaults.object(forKey: MacAppKeys.pasteLastHotkeyModifiers) as? UInt64

        self.currentKeyCode = savedKeyCode.map { UInt16($0) } ?? Self.defaultKeyCode
        self.currentModifiers = savedModifiers.map { CGEventFlags(rawValue: $0) } ?? Self.defaultModifiers
        self.currentTranslationKeyCode = savedTranslationKeyCode.map { UInt16($0) } ?? Self.defaultTranslationKeyCode
        self.currentTranslationModifiers = savedTranslationModifiers.map { CGEventFlags(rawValue: $0) } ?? Self.defaultTranslationModifiers
        self.currentPasteLastKeyCode = savedPasteLastKeyCode.map { UInt16($0) } ?? Self.defaultPasteLastKeyCode
        self.currentPasteLastModifiers = savedPasteLastModifiers.map { CGEventFlags(rawValue: $0) } ?? Self.defaultPasteLastModifiers

        resolveInitialHotkeyConflicts()
    }

    // MARK: - Public API

    /// Starts listening for the configured hotkey.
    /// Attempts CGEvent tap first; falls back to NSEvent global monitor if Accessibility is not granted.
    func start() {
        stop()

        if AXIsProcessTrusted() {
            startEventTap()
        }

        if !isEventTapActive {
            startGlobalMonitorFallback()
        }
    }

    /// Stops listening for the hotkey and tears down tap / monitor.
    func stop() {
        tearDownEventTap()
        tearDownGlobalMonitor()
    }

    /// Updates the hotkey to a new key code and modifiers, persists to UserDefaults, and restarts the listener.
    @discardableResult
    func updateHotkey(kind: HotkeyKind = .dictation, keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        guard !conflictsWithExistingHotkey(kind: kind, keyCode: keyCode, modifiers: modifiers) else {
            logger.warning("[phase:hotkey_update_rejected] reason=duplicate kind=\(String(describing: kind), privacy: .public)")
            return false
        }

        switch kind {
        case .dictation:
            currentKeyCode = keyCode
            currentModifiers = modifiers
            defaults.set(Int(keyCode), forKey: MacAppKeys.hotkeyKeyCode)
            defaults.set(modifiers.rawValue, forKey: MacAppKeys.hotkeyModifiers)
        case .translation:
            currentTranslationKeyCode = keyCode
            currentTranslationModifiers = modifiers
            defaults.set(Int(keyCode), forKey: MacAppKeys.translationHotkeyKeyCode)
            defaults.set(modifiers.rawValue, forKey: MacAppKeys.translationHotkeyModifiers)
        case .pasteLast:
            currentPasteLastKeyCode = keyCode
            currentPasteLastModifiers = modifiers
            defaults.set(Int(keyCode), forKey: MacAppKeys.pasteLastHotkeyKeyCode)
            defaults.set(modifiers.rawValue, forKey: MacAppKeys.pasteLastHotkeyModifiers)
        }

        // Restart with new hotkey
        start()
        return true
    }

    func formattedHotkey(for kind: HotkeyKind) -> String {
        let hotkey = currentHotkey(for: kind)
        return Self.modifierSymbols(for: hotkey.modifiers) + Self.keyCodeToString(hotkey.keyCode)
    }

    func conflictsWithExistingHotkey(kind: HotkeyKind, keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        HotkeyKind.allCases
            .filter { $0 != kind }
            .contains { otherKind in
                let otherHotkey = currentHotkey(for: otherKind)
                return matches(
                    keyCode: keyCode,
                    modifiers: modifiers,
                    targetKeyCode: otherHotkey.keyCode,
                    targetModifiers: otherHotkey.modifiers
                )
            }
    }

    private func resolveInitialHotkeyConflicts() {
        var occupied = [(keyCode: currentKeyCode, modifiers: currentModifiers)]

        if Self.hotkey(keyCode: currentTranslationKeyCode, modifiers: currentTranslationModifiers, conflictsWith: occupied) {
            let replacement = Self.firstAvailableFallbackHotkey(preferredKind: .translation, occupied: occupied)
            currentTranslationKeyCode = replacement.keyCode
            currentTranslationModifiers = replacement.modifiers
            defaults.set(Int(replacement.keyCode), forKey: MacAppKeys.translationHotkeyKeyCode)
            defaults.set(replacement.modifiers.rawValue, forKey: MacAppKeys.translationHotkeyModifiers)
        }
        occupied.append((currentTranslationKeyCode, currentTranslationModifiers))

        if Self.hotkey(keyCode: currentPasteLastKeyCode, modifiers: currentPasteLastModifiers, conflictsWith: occupied) {
            let replacement = Self.firstAvailableFallbackHotkey(preferredKind: .pasteLast, occupied: occupied)
            currentPasteLastKeyCode = replacement.keyCode
            currentPasteLastModifiers = replacement.modifiers
            defaults.set(Int(replacement.keyCode), forKey: MacAppKeys.pasteLastHotkeyKeyCode)
            defaults.set(replacement.modifiers.rawValue, forKey: MacAppKeys.pasteLastHotkeyModifiers)
        }
    }

    deinit {
        stop()
    }

    private func currentHotkey(for kind: HotkeyKind) -> (keyCode: UInt16, modifiers: CGEventFlags) {
        switch kind {
        case .dictation:
            return (currentKeyCode, currentModifiers)
        case .translation:
            return (currentTranslationKeyCode, currentTranslationModifiers)
        case .pasteLast:
            return (currentPasteLastKeyCode, currentPasteLastModifiers)
        }
    }

    // MARK: - CGEvent Tap

    private func startEventTap() {
        // Pass self as userInfo via Unmanaged pointer
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventTapCallback,
            userInfo: userInfo
        ) else {
            // CGEvent tap creation failed (likely no Accessibility permission)
            isEventTapActive = false
            return
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            tearDownEventTap()
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEventTapActive = true
    }

    private func tearDownEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        isEventTapActive = false
    }

    // MARK: - NSEvent Global Monitor Fallback

    private func startGlobalMonitorFallback() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }

            let keyCode = UInt16(event.keyCode)
            let modifiers = event.modifierFlags.cgEventFlags

            if self.matchesDictationHotkey(keyCode: keyCode, modifiers: modifiers) {
                self.logger.info(
                    "[phase:hotkey_detected] source=global_monitor keyCode=\(keyCode) modifiers=\(modifiers.rawValue, privacy: .public)"
                )
                self.onHotkeyPressed?()
            } else if self.matchesTranslationHotkey(keyCode: keyCode, modifiers: modifiers) {
                self.logger.info(
                    "[phase:translation_hotkey_detected] source=global_monitor keyCode=\(keyCode) modifiers=\(modifiers.rawValue, privacy: .public)"
                )
                self.onTranslationHotkeyPressed?()
            } else if self.matchesPasteLastHotkey(keyCode: keyCode, modifiers: modifiers) {
                self.logger.info("[phase:paste_last_hotkey_detected] source=global_monitor")
                self.onPasteLastPressed?()
            }

            // ESC key (keyCode 53) with no modifiers → cancel recording (only when active)
            if keyCode == 53, modifiers.isEmpty, self.isRecordingActive?() == true {
                self.logger.info("[phase:esc_hotkey_detected] source=global_monitor")
                self.onEscPressed?()
            }
        }
    }

    private func tearDownGlobalMonitor() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    // MARK: - Hotkey Matching

    /// Checks if the given CGEvent matches the configured hotkey.
    fileprivate func matchesHotkey(_ event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags.intersection(Self.relevantModifierMask)
        return matchesDictationHotkey(keyCode: keyCode, modifiers: eventModifiers)
    }

    fileprivate func matchesTranslationHotkey(_ event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags.intersection(Self.relevantModifierMask)
        return matchesTranslationHotkey(keyCode: keyCode, modifiers: eventModifiers)
    }

    fileprivate func matchesPasteLastHotkey(_ event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags.intersection(Self.relevantModifierMask)
        return matchesPasteLastHotkey(keyCode: keyCode, modifiers: eventModifiers)
    }

    private func matchesDictationHotkey(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        matches(
            keyCode: keyCode,
            modifiers: modifiers,
            targetKeyCode: currentKeyCode,
            targetModifiers: currentModifiers
        )
    }

    private func matchesTranslationHotkey(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        matches(
            keyCode: keyCode,
            modifiers: modifiers,
            targetKeyCode: currentTranslationKeyCode,
            targetModifiers: currentTranslationModifiers
        )
    }

    private func matchesPasteLastHotkey(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        matches(
            keyCode: keyCode,
            modifiers: modifiers,
            targetKeyCode: currentPasteLastKeyCode,
            targetModifiers: currentPasteLastModifiers
        )
    }

    private func matches(
        keyCode: UInt16,
        modifiers: CGEventFlags,
        targetKeyCode: UInt16,
        targetModifiers: CGEventFlags
    ) -> Bool {
        let eventModifiers = modifiers.intersection(Self.relevantModifierMask)
        let expectedModifiers = targetModifiers.intersection(Self.relevantModifierMask)
        return keyCode == targetKeyCode && eventModifiers == expectedModifiers
    }

    private static let relevantModifierMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]
}

extension HotkeyManager {
    private static let fallbackHotkeyKeyCodes: [UInt16] = [
        defaultTranslationKeyCode,
        defaultPasteLastKeyCode,
        defaultKeyCode,
        5,  // G
        4,  // H
        17, // T
        16, // Y
        8,  // C
        11  // B
    ]

    private static func firstAvailableFallbackHotkey(
        preferredKind: HotkeyKind,
        occupied: [(keyCode: UInt16, modifiers: CGEventFlags)]
    ) -> (keyCode: UInt16, modifiers: CGEventFlags) {
        let preferred = currentDefaultHotkey(for: preferredKind)
        if !hotkey(keyCode: preferred.keyCode, modifiers: preferred.modifiers, conflictsWith: occupied) {
            return preferred
        }

        for keyCode in fallbackHotkeyKeyCodes
        where !hotkey(keyCode: keyCode, modifiers: defaultModifiers, conflictsWith: occupied) {
            return (keyCode, defaultModifiers)
        }

        return preferred
    }

    private static func currentDefaultHotkey(for kind: HotkeyKind) -> (keyCode: UInt16, modifiers: CGEventFlags) {
        switch kind {
        case .dictation:
            return (defaultKeyCode, defaultModifiers)
        case .translation:
            return (defaultTranslationKeyCode, defaultTranslationModifiers)
        case .pasteLast:
            return (defaultPasteLastKeyCode, defaultPasteLastModifiers)
        }
    }

    private static func hotkey(
        keyCode: UInt16,
        modifiers: CGEventFlags,
        conflictsWith occupied: [(keyCode: UInt16, modifiers: CGEventFlags)]
    ) -> Bool {
        occupied.contains { existing in
            keyCode == existing.keyCode
                && modifiers.intersection(relevantModifierMask) == existing.modifiers.intersection(relevantModifierMask)
        }
    }

    static func modifierSymbols(for flags: CGEventFlags) -> String {
        var result = ""
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskShift) { result += "⇧" }
        if flags.contains(.maskCommand) { result += "⌘" }
        return result
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return AppText.hotkeyKeyName(for: keyCode) ?? "Enter"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return AppText.hotkeyKeyName(for: keyCode) ?? "Tab"
        case 49: return AppText.hotkeyKeyName(for: keyCode) ?? "Space"
        case 50: return "`"
        case 51: return AppText.hotkeyKeyName(for: keyCode) ?? "Delete"
        case 53: return AppText.hotkeyKeyName(for: keyCode) ?? "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return AppText.unknownHotkeyKeyName(for: keyCode)
        }
    }
}

// MARK: - CGEvent Tap Callback (C function pointer)

/// Top-level C callback for the CGEvent tap. Cannot capture Swift context, so we recover the
/// HotkeyManager instance from the `userInfo` pointer.
private func hotkeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap is disabled by the system (e.g., timeout), re-enable it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    if manager.matchesHotkey(event) {
        manager.logger.info(
            "[phase:hotkey_detected] source=event_tap keyCode=\(manager.currentKeyCode) modifiers=\(manager.currentModifiers.rawValue, privacy: .public)"
        )
        DispatchQueue.main.async {
            manager.onHotkeyPressed?()
        }
        return nil
    }

    if manager.matchesTranslationHotkey(event) {
        manager.logger.info(
            "[phase:translation_hotkey_detected] source=event_tap keyCode=\(manager.currentTranslationKeyCode) modifiers=\(manager.currentTranslationModifiers.rawValue, privacy: .public)"
        )
        DispatchQueue.main.async {
            manager.onTranslationHotkeyPressed?()
        }
        return nil
    }

    if manager.matchesPasteLastHotkey(event) {
        manager.logger.info("[phase:paste_last_hotkey_detected] source=event_tap")
        DispatchQueue.main.async {
            manager.onPasteLastPressed?()
        }
        return nil
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let relevantMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]
    let eventModifiers = event.flags.intersection(relevantMask)

    // ESC key (keyCode 53) with no modifiers → cancel recording (only when active)
    let escKeyCode: UInt16 = 53
    if keyCode == escKeyCode, eventModifiers.isEmpty,
       manager.isRecordingActive?() == true {
        manager.logger.info("[phase:esc_hotkey_detected] source=event_tap")
        DispatchQueue.main.async {
            manager.onEscPressed?()
        }
        return nil // Suppress ESC so it doesn't reach the underlying app
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - NSEvent.ModifierFlags → CGEventFlags Conversion

private extension NSEvent.ModifierFlags {
    /// Converts NSEvent modifier flags to CGEventFlags for comparison.
    var cgEventFlags: CGEventFlags {
        var flags = CGEventFlags()
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}
