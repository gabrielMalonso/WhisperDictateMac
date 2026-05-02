import SwiftData
import Foundation

@Model
class ReplacementRule {
    var id: UUID = UUID()
    var originalText: String = ""
    var replacementText: String = ""
    var isEnabled: Bool = true
    var createdAt: Date = Date()
    var useCount: Int = 0
    var updatedAt: Date = Date()

    init(originalText: String, replacementText: String) {
        self.id = UUID()
        self.originalText = originalText
        self.replacementText = replacementText
        self.isEnabled = true
        self.createdAt = .now
        self.useCount = 0
        self.updatedAt = .now
    }
}
