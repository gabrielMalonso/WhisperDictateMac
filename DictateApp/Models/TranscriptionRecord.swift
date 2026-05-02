import SwiftData
import Foundation

@Model
class TranscriptionRecord {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var wordCount: Int = 0
    var durationSeconds: Double = 0
    var language: String = "pt"

    init(
        text: String,
        createdAt: Date = .now,
        wordCount: Int? = nil,
        durationSeconds: Double = 0,
        language: String = "pt"
    ) {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
        self.wordCount = wordCount ?? text.split(separator: " ").count
        self.durationSeconds = durationSeconds
        self.language = language
    }
}

extension TranscriptionRecord {
    func compactMetadata(to now: Date = .now) -> String {
        "\(createdAt.relativeShort(to: now)) · \(compactMetadataDetails)"
    }

    var compactMetadataDetails: String {
        "\(localizedWordCount) · \(formattedAudioDuration)"
    }

    var formattedAudioDuration: String {
        let totalSeconds = max(Int(durationSeconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    var localizedWordCount: String {
        AppText.wordCount(wordCount)
    }
}
