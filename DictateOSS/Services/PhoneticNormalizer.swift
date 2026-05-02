import Foundation

enum PhoneticNormalizer {

    static func normalize(_ input: String) -> String {
        var result = input
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)

        // Silent initial H
        if result.hasPrefix("h") {
            result = String(result.dropFirst())
        }

        // Digraph normalizations (multi-char first)
        let digraphs: [(String, String)] = [
            ("ss", "s"),
            ("ch", "x"),
            ("lh", "l"),
            ("nh", "n"),
            ("ph", "f"),
            ("ou", "o")
        ]
        for (from, to) in digraphs {
            result = result.replacingOccurrences(of: from, with: to)
        }

        // Single-char equivalences
        let singles: [(Character, Character)] = [
            ("z", "s"),
            ("w", "v"),
            ("y", "i")
        ]
        for (from, to) in singles {
            result = String(result.map { $0 == from ? to : $0 })
        }

        return result
    }
}
