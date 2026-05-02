import Foundation

enum MacAppKeys {
    // MARK: - Transcription Settings

    static let transcriptionLanguage = "transcriptionLanguage"
    static let transcriptionDomain = "transcriptionDomain"
    static let formattingOptions = "formattingOptions"
    static let replacementRulesEnabled = "replacementRulesEnabled"
    static let dictionaryEnabled = "dictionaryEnabled"
    static let mlxExecutablePath = "mlxExecutablePath"
    static let mlxModel = "mlxModel"

    // MARK: - Translation

    static let translationEnabled = "translationEnabled"
    static let translationTargetLanguage = "translationTargetLanguage"

    // MARK: - Appearance

    static let keyboardAccentColor = "keyboardAccentColor"

    // MARK: - Onboarding

    static let onboardingCompleted = "onboardingCompleted"
    static let allowUnauthenticatedAccess = "allowUnauthenticatedAccess"

    // MARK: - Server Sync

    static let syncInitialPushCompleted = "syncInitialPushCompleted"
    static let syncLastPullDate = "syncLastPullDate"
    static let syncLastPullCursor = "syncLastPullCursor"
    static let syncTotalDictations = "syncTotalDictations"
    static let syncTotalWords = "syncTotalWords"
    static let syncTotalDurationSeconds = "syncTotalDurationSeconds"

    // MARK: - Server-computed Stats
    static let syncWeekDictations = "syncWeekDictations"
    static let syncWeekWords = "syncWeekWords"
    static let syncCurrentStreak = "syncCurrentStreak"
    static let syncLongestStreak = "syncLongestStreak"
    static let syncBestDayDate = "syncBestDayDate"
    static let syncBestDayDictations = "syncBestDayDictations"
    static let syncThisMonthDictations = "syncThisMonthDictations"
    static let syncLast7DaysDictations = "syncLast7DaysDictations"
    static let syncWeeklyChart = "syncWeeklyChart"

    // MARK: - Weekly Usage

    static let weeklyUsed = "weeklyUsed"
    static let weeklyLimit = "weeklyLimit"
    static let weeklyResetsAt = "weeklyResetsAt"
    static let hourlyUsed = "hourlyUsed"
    static let hourlyLimit = "hourlyLimit"

    // MARK: - macOS-Specific

    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let translationHotkeyKeyCode = "translationHotkeyKeyCode"
    static let translationHotkeyModifiers = "translationHotkeyModifiers"
    static let pasteLastHotkeyKeyCode = "pasteLastHotkeyKeyCode"
    static let pasteLastHotkeyModifiers = "pasteLastHotkeyModifiers"
    static let launchAtLogin = "launchAtLogin"
    static let preferredMicrophoneID = "preferredMicrophoneID"

    // MARK: - Overlay & Feedback

    static let overlayPosition = "overlayPosition"
    static let soundFeedbackEnabled = "soundFeedbackEnabled"
    static let soundFeedbackVolume = "soundFeedbackVolume"
}
