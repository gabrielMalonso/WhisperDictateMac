enum PendingInsertionPolicy {
    static func textToInsert(rawText: String, contextBefore: String?) -> String {
        guard shouldPrefixSpace(rawText: rawText, contextBefore: contextBefore) else {
            return rawText
        }
        return " \(rawText)"
    }

    private static func shouldPrefixSpace(rawText: String, contextBefore: String?) -> Bool {
        guard !rawText.isEmpty else { return false }
        guard let firstCharacter = rawText.first, !firstCharacter.isWhitespace else { return false }
        guard let previousCharacter = contextBefore?.last else { return false }
        return !previousCharacter.isWhitespace
    }
}
