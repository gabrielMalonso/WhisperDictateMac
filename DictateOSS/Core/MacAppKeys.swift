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
    static let aiMode = "aiMode"
    static let transcriptionProvider = "transcriptionProvider"
    static let llmProvider = "llmProvider"
    static let groqWhisperModel = "groqWhisperModel"
    static let groqLLMModel = "groqLLMModel"
    static let localLLMModel = "localLLMModel"
    static let groqFallbackToLocal = "groqFallbackToLocal"

    // MARK: - Translation

    static let translationEnabled = "translationEnabled"
    static let translationTargetLanguage = "translationTargetLanguage"

    // MARK: - Appearance

    static let keyboardAccentColor = "keyboardAccentColor"

    // MARK: - Onboarding

    static let onboardingCompleted = "onboardingCompleted"
    static let openAISettingsAfterOnboarding = "openAISettingsAfterOnboarding"

    // MARK: - Local Stats

    static let localTotalDictations = "localTotalDictations"
    static let localTotalWords = "localTotalWords"
    static let localTotalDurationSeconds = "localTotalDurationSeconds"
    static let localWeekDictations = "localWeekDictations"
    static let localWeekWords = "localWeekWords"
    static let localCurrentStreak = "localCurrentStreak"
    static let localLongestStreak = "localLongestStreak"
    static let localBestDayDate = "localBestDayDate"
    static let localBestDayDictations = "localBestDayDictations"
    static let localThisMonthDictations = "localThisMonthDictations"
    static let localLast7DaysDictations = "localLast7DaysDictations"
    static let localWeeklyChart = "localWeeklyChart"

    // MARK: - Local Usage

    static let weeklyUsageCount = "weeklyUsageCount"
    static let weeklyUsageGoal = "weeklyUsageGoal"
    static let weeklyUsageResetsAt = "weeklyUsageResetsAt"

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
