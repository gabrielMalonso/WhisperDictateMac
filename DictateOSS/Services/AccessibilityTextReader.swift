import AppKit

enum AccessibilityTextReader {
    static func characterBeforeCursor() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(pid)

        guard let focusedElement: AXUIElement = copyAttribute(appElement, kAXFocusedUIElementAttribute) else { return nil }

        guard let selectedRange: AXValue = copyAttribute(focusedElement, kAXSelectedTextRangeAttribute) else { return nil }

        var range = CFRange()
        guard AXValueGetValue(selectedRange, .cfRange, &range) else { return nil }
        guard range.location > 0 else { return nil }

        // Fetch up to 2 UTF-16 code units to correctly capture surrogate pairs (emoji, etc.)
        let fetchLength = min(range.location, 2)
        var charRange = CFRange(location: range.location - fetchLength, length: fetchLength)
        guard let axRange = AXValueCreate(.cfRange, &charRange) else { return nil }

        var textValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXStringForRangeParameterizedAttribute as CFString,
            axRange,
            &textValue
        ) == .success,
              let text = textValue as? String,
              let lastCharacter = text.last else { return nil }

        return String(lastCharacter)
    }

    // MARK: - Private

    private static func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        return value as? T
    }
}
