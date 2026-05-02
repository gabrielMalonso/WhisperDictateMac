import Foundation
import SwiftData

enum ReplacementEngine {

    static func apply(rules: [ReplacementRule], to text: String, context: ModelContext) -> (text: String, replacementCount: Int) {
        guard !rules.isEmpty else { return (text, 0) }

        var result = text
        var totalCount = 0

        for rule in rules where rule.isEnabled {
            guard let regex = buildNormalizedPattern(for: rule.originalText) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matchCount = regex.numberOfMatches(in: result, range: range)
            if matchCount > 0 {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: rule.replacementText)
                )
                rule.useCount += matchCount
                totalCount += matchCount
            }
        }

        if totalCount > 0 {
            try? context.save()
        }

        return (result, totalCount)
    }

    private static func buildNormalizedPattern(for trigger: String) -> NSRegularExpression? {
        let separators = CharacterSet.punctuationCharacters.union(.whitespaces)
        let words = trigger.components(separatedBy: separators).filter { !$0.isEmpty }

        if words.isEmpty {
            // Trigger is purely punctuation -- match literally
            return try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: trigger),
                options: .caseInsensitive
            )
        }

        // Single or multi-word: join escaped words with flexible punctuation/whitespace separator.
        let termPattern = words
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "[\\p{P}\\s]+")
        let pattern = "(?<![\\p{L}\\p{N}])\(termPattern)(?![\\p{L}\\p{N}])"

        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
}
