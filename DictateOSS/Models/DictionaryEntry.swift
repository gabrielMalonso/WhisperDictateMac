import SwiftData
import Foundation

@Model
class DictionaryEntry {
    var id: UUID = UUID()
    var term: String = ""
    var language: String = ""
    var source: String = "manual"
    var useCount: Int = 0
    var lastUsedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(term: String, language: String, source: String = "manual") {
        self.id = UUID()
        self.term = term
        self.language = language
        self.source = source
        self.useCount = 0
        self.lastUsedAt = .now
        self.createdAt = .now
        self.updatedAt = .now
    }
}
