import Foundation

func formatRecordingTimer(seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return "\(m):\(String(format: "%02d", s))"
}

func checkNearRecordingLimit(elapsedSeconds: Int) -> Bool {
    elapsedSeconds >= Int(AppConfig.maxRecordingDuration) - AppConfig.recordingWarningThreshold
}
