import Foundation

// MARK: - Punctuation stripping result

struct StrippedWord {
    let clean: String
    let leading: String
    let trailing: String
}

// MARK: - Match result

struct MatchResult: Comparable {
    enum Category: Int, Comparable {
        case exact = 0
        case levenshtein = 1
        case phonetic = 2

        static func < (lhs: Category, rhs: Category) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let term: String
    let category: Category
    let distance: Int

    static func < (lhs: MatchResult, rhs: MatchResult) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }
        return lhs.distance < rhs.distance
    }
}

// MARK: - DictionaryMatcher

enum DictionaryMatcher {

    /// Applies dictionary terms to transcription text using fuzzy matching.
    /// Returns the corrected text with dictionary terms applied.
    /// If dictionary is empty, returns the original text unchanged.
    static func apply(terms: [String], to text: String, language: String = "auto") -> String {
        guard !terms.isEmpty, !text.isEmpty else { return text }

        var result = text

        // Separate single-word and multi-word terms
        let singleWordTerms = terms.filter { !$0.contains(" ") }
        let multiWordTerms = terms.filter { $0.contains(" ") }

        // Apply multi-word terms first (n-gram matching)
        for term in multiWordTerms {
            result = applyMultiWordTerm(term, to: result)
        }

        // Apply single-word terms
        result = applySingleWordTerms(singleWordTerms, to: result, language: language)

        return result
    }

    // MARK: - Single word matching

    private static func applySingleWordTerms(_ terms: [String], to text: String, language: String) -> String {
        let words = text.components(separatedBy: " ")
        var resultWords = words

        for (index, word) in words.enumerated() {
            let stripped = stripPunctuation(word)
            guard !stripped.clean.isEmpty else { continue }

            if let matchedTerm = bestMatchingTerm(for: stripped.clean, in: terms, language: language) {
                resultWords[index] = stripped.leading + matchedTerm + stripped.trailing
            }
        }

        return resultWords.joined(separator: " ")
    }

    /// Evaluates all terms and returns the best match, or nil if no term matches.
    private static func bestMatchingTerm(for word: String, in terms: [String], language: String) -> String? {
        let wordIsKnown = SpellCheckService.isKnownWord(word.lowercased(), language: language)

        var bestMatch: MatchResult?

        for term in terms {
            guard let result = score(word: word, term: term) else { continue }

            if wordIsKnown && result.category != .exact {
                continue
            }

            if let current = bestMatch {
                if result < current {
                    bestMatch = result
                }
            } else {
                bestMatch = result
            }
        }

        return bestMatch?.term
    }

    /// Returns the maximum allowed Levenshtein distance based on term length.
    private static func dynamicThreshold(for length: Int) -> Int {
        switch length {
        case ..<3:  return 0
        case 3...4: return 1
        case 5...7: return 2
        case 8...11: return 3
        default:    return 4
        }
    }

    /// Scores a word against a term. Returns a MatchResult if the word matches, or nil.
    private static func score(word: String, term: String) -> MatchResult? {
        let wordLower = word.lowercased()
        let termLower = term.lowercased()

        if wordLower == termLower {
            return MatchResult(term: term, category: .exact, distance: 0)
        }

        if term.count < 3 {
            return nil
        }

        let levDistance = levenshteinDistance(wordLower, termLower)
        let threshold = dynamicThreshold(for: term.count)
        if levDistance <= threshold {
            return MatchResult(term: term, category: .levenshtein, distance: levDistance)
        }

        let phoneticDistance = levenshteinDistance(
            PhoneticNormalizer.normalize(wordLower),
            PhoneticNormalizer.normalize(termLower)
        )
        let maxPhoneticDistance = term.count < 5 ? 1 : 2
        if phoneticDistance <= maxPhoneticDistance {
            return MatchResult(term: term, category: .phonetic, distance: phoneticDistance)
        }

        return nil
    }

    // MARK: - Multi-word (n-gram) matching

    private static func applyMultiWordTerm(_ term: String, to text: String) -> String {
        let termWords = term.components(separatedBy: " ").filter { !$0.isEmpty }
        let wordCount = termWords.count
        guard wordCount > 0 else { return text }

        var textWords = text.components(separatedBy: " ")
        guard textWords.count >= wordCount else { return text }

        var idx = 0
        while idx <= textWords.count - wordCount {
            let window = textWords[idx..<(idx + wordCount)].map { stripPunctuation($0).clean }

            let allMatch = zip(window, termWords).allSatisfy { score(word: $0, term: $1) != nil }

            if allMatch {
                // Replace the window with the term words, preserving punctuation of first and last
                let leadingPunct = stripPunctuation(textWords[idx]).leading
                let trailingPunct = stripPunctuation(textWords[idx + wordCount - 1]).trailing

                var replacement = termWords
                replacement[0] = leadingPunct + replacement[0]
                replacement[wordCount - 1] += trailingPunct

                textWords.replaceSubrange(idx..<(idx + wordCount), with: replacement)
                idx += wordCount // skip past the replaced words
            } else {
                idx += 1
            }
        }

        return textWords.joined(separator: " ")
    }

    // MARK: - Levenshtein Distance

    static func levenshteinDistance(_ firstString: String, _ secondString: String) -> Int {
        let firstArray = Array(firstString)
        let secondArray = Array(secondString)
        let firstLen = firstArray.count
        let secondLen = secondArray.count

        if firstLen == 0 { return secondLen }
        if secondLen == 0 { return firstLen }

        // Use two rows instead of full matrix for space efficiency
        var previousRow = Array(0...secondLen)
        var currentRow = Array(repeating: 0, count: secondLen + 1)

        for row in 1...firstLen {
            currentRow[0] = row
            for col in 1...secondLen {
                let cost = firstArray[row - 1] == secondArray[col - 1] ? 0 : 1
                currentRow[col] = min(
                    currentRow[col - 1] + 1,      // insertion
                    previousRow[col] + 1,          // deletion
                    previousRow[col - 1] + cost    // substitution
                )
            }
            previousRow = currentRow
        }

        return previousRow[secondLen]
    }

    // MARK: - Helpers

    private static func stripPunctuation(_ word: String) -> StrippedWord {
        let punctuation = CharacterSet.punctuationCharacters.union(.symbols)

        var leading = ""
        var trailing = ""
        var clean = word

        // Strip leading punctuation
        while let first = clean.unicodeScalars.first, punctuation.contains(first) {
            leading.append(Character(first))
            clean.removeFirst()
        }

        // Strip trailing punctuation
        while let last = clean.unicodeScalars.last, punctuation.contains(last) {
            trailing = String(Character(last)) + trailing
            clean.removeLast()
        }

        return StrippedWord(clean: clean, leading: leading, trailing: trailing)
    }
}
