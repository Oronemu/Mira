import Foundation

/// Pure helpers that operate on entry content + cursor. State containers on
/// both edit and create flows delegate here so list toggling, indent/outdent,
/// and Enter-continue logic stay in one place.
///
/// Cursor positions are expressed in **character offsets** (Swift `Character`
/// counts from the start of the string) rather than UTF-16 offsets. That
/// matches `AttributedString.CharacterView` indexing and sidesteps the
/// UTF-16 vs grapheme divergence that bit the earlier String-based version.
public enum EntryContentEditor {

    // MARK: - Types

    public enum ListAction: Sendable, Hashable {
        case toggleBullet
        case toggleNumbered
        case indent
        case outdent
    }

    public struct LineInfo: Sendable, Hashable {
        public let token: EntryLineToken
        public let charRange: Range<Int>      // character offsets
        public let hasTrailingNewline: Bool
    }

    public struct MutationResult: Sendable, Hashable {
        public let content: AttributedString
        public let cursorCharOffset: Int
    }

    // MARK: - Line analysis

    /// Returns info about the line containing the given character offset.
    public static func lineInfo(in content: AttributedString, at charOffset: Int) -> LineInfo? {
        let plain = String(content.characters)
        let clamped = max(0, min(charOffset, plain.count))
        let plainIdx = plain.index(plain.startIndex, offsetBy: clamped)
        let lineRange = plain.lineRange(for: plainIdx..<plainIdx)
        let lineText = String(plain[lineRange])
        let hasNewline = lineText.hasSuffix("\n")
        let body = hasNewline ? String(lineText.dropLast()) : lineText
        let token = EntryContentParser.tokenize(line: body)
        let startChar = plain.distance(from: plain.startIndex, to: lineRange.lowerBound)
        let endChar = plain.distance(from: plain.startIndex, to: lineRange.upperBound)
        return LineInfo(
            token: token,
            charRange: startChar..<endChar,
            hasTrailingNewline: hasNewline
        )
    }

    // MARK: - List actions

    /// Applies a list action to the line containing the cursor. Returns the
    /// mutated content + the cursor position parked at end of the new line
    /// (before any trailing newline). Attributes on characters outside the
    /// replaced line range are preserved; the replaced body inherits the
    /// attributes of the first character of the old line.
    public static func applyListAction(
        _ action: ListAction,
        in content: AttributedString,
        at charOffset: Int
    ) -> MutationResult? {
        guard let info = lineInfo(in: content, at: charOffset) else { return nil }
        let newBody = transformLine(info.token, action: action)
        let newLine = newBody + (info.hasTrailingNewline ? "\n" : "")

        var mutated = content
        let start = charIndex(in: mutated, offset: info.charRange.lowerBound)
        let end = charIndex(in: mutated, offset: info.charRange.upperBound)
        mutated.characters.replaceSubrange(start..<end, with: newLine)

        let newCursorChar = info.charRange.lowerBound + newBody.count
        return MutationResult(content: mutated, cursorCharOffset: newCursorChar)
    }

    // MARK: - Enter continuation

    /// Called on every content change in the editor. If the user just pressed
    /// Return after a list item, we either (a) insert a matching marker on
    /// the new line, or (b) if the previous marker had no text, strip it and
    /// exit list mode. Returns nil when no adjustment is needed.
    public static func handleEnterContinuation(
        oldContent: AttributedString,
        newContent: AttributedString,
        cursorCharOffset: Int
    ) -> MutationResult? {
        let oldCount = oldContent.characters.count
        let newCount = newContent.characters.count
        guard newCount == oldCount + 1 else { return nil }
        guard cursorCharOffset > 0 else { return nil }

        let insertionChar = cursorCharOffset - 1
        let plain = String(newContent.characters)
        guard insertionChar < plain.count else { return nil }
        let insertionPlainIdx = plain.index(plain.startIndex, offsetBy: insertionChar)
        guard plain[insertionPlainIdx] == "\n" else { return nil }

        guard let prevInfo = lineInfo(in: newContent, at: max(0, insertionChar - 1)) else {
            return nil
        }
        let prev = prevInfo.token
        guard prev.kind != .paragraph else { return nil }

        let trimmedText = prev.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            // Empty marker + Enter → clear the previous line entirely (including
            // the just-inserted newline), leaving the cursor on the now-empty line.
            var mutated = newContent
            let lineStart = charIndex(in: mutated, offset: prevInfo.charRange.lowerBound)
            let lineEnd = charIndex(in: mutated, offset: prevInfo.charRange.upperBound)
            mutated.characters.replaceSubrange(lineStart..<lineEnd, with: "")
            return MutationResult(
                content: mutated,
                cursorCharOffset: prevInfo.charRange.lowerBound
            )
        }

        // Non-empty: insert a matching marker right after the new \n.
        let marker: String
        switch prev.kind {
        case .bullet:
            marker = String(repeating: "  ", count: prev.indent) + "- "
        case .numbered:
            let next = (prev.number ?? 1) + 1
            marker = String(repeating: "  ", count: prev.indent) + "\(next). "
        case .paragraph:
            return nil
        }

        var mutated = newContent
        let insertionPoint = charIndex(in: mutated, offset: cursorCharOffset)
        mutated.characters.insert(contentsOf: marker, at: insertionPoint)
        return MutationResult(
            content: mutated,
            cursorCharOffset: cursorCharOffset + marker.count
        )
    }

    // MARK: - Private

    private static func transformLine(
        _ token: EntryLineToken,
        action: ListAction
    ) -> String {
        let indentSpaces = String(repeating: "  ", count: token.indent)
        switch action {
        case .toggleBullet:
            return indentSpaces + (token.kind == .bullet ? token.text : "- " + token.text)
        case .toggleNumbered:
            return indentSpaces + (token.kind == .numbered ? token.text : "1. " + token.text)
        case .indent:
            let newIndent = token.indent + 1
            return String(repeating: "  ", count: newIndent) + markerPrefix(for: token.kind) + token.text
        case .outdent:
            let newIndent = max(0, token.indent - 1)
            return String(repeating: "  ", count: newIndent) + markerPrefix(for: token.kind) + token.text
        }
    }

    private static func markerPrefix(for kind: EntryLineToken.Kind) -> String {
        switch kind {
        case .bullet: "- "
        case .numbered: "1. "
        case .paragraph: ""
        }
    }

    /// Safely derives an `AttributedString.Index` from a character offset.
    private static func charIndex(in content: AttributedString, offset: Int) -> AttributedString.Index {
        let chars = content.characters
        let clamped = max(0, min(offset, chars.count))
        return chars.index(chars.startIndex, offsetBy: clamped)
    }
}
