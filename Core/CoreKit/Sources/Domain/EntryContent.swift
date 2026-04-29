import Foundation

/// A single top-level block in an entry body. Produced by `EntryContentParser`
/// and consumed by the renderer in `DesignSystem` plus the editor state
/// (which needs it to know what kind of line the cursor sits on).
///
/// Each block carries a `textRange` of character offsets into the plain-text
/// representation of the content — renderers use this to extract the
/// corresponding `AttributedString` slice with its original run-level
/// attributes intact.
public enum EntryContentBlock: Sendable, Hashable {
    case paragraph(text: String, textRange: Range<Int>)
    case list(EntryListBlock)
}

public struct EntryListBlock: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case bullet
        case numbered
    }

    public let kind: Kind
    public let items: [EntryListItem]

    public init(kind: Kind, items: [EntryListItem]) {
        self.kind = kind
        self.items = items
    }
}

public struct EntryListItem: Sendable, Hashable {
    public let text: String
    /// Character-offset range of the item's body (after the marker, before
    /// the trailing newline) within the document's plain-text view. Used
    /// by the renderer to pull the matching AttributedString slice.
    public let textRange: Range<Int>
    public let children: [EntryListBlock]

    public init(text: String, textRange: Range<Int>, children: [EntryListBlock] = []) {
        self.text = text
        self.textRange = textRange
        self.children = children
    }
}

/// Per-line classification — used both by the parser and by the state layer
/// to reason about the line under the cursor without running the full tree
/// build.
public struct EntryLineToken: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case paragraph
        case bullet
        case numbered
    }

    public let indent: Int       // nesting level (1 level = 2 leading spaces)
    public let kind: Kind
    public let text: String      // marker stripped, leading spaces stripped
    /// The literal number parsed from a numbered-list line (e.g. `3` for
    /// `"3. foo"`). Nil for bullet/paragraph lines.
    public let number: Int?

    public init(indent: Int, kind: Kind, text: String, number: Int? = nil) {
        self.indent = indent
        self.kind = kind
        self.text = text
        self.number = number
    }
}

public enum EntryContentParser {
    // MARK: - Public

    /// Parses the full content into top-level blocks with character ranges.
    public static func parse(_ content: String) -> [EntryContentBlock] {
        let lines = content.components(separatedBy: "\n")
        var annotated: [AnnotatedLine] = []
        var lineStart = 0
        for (idx, raw) in lines.enumerated() {
            let token = tokenize(line: raw)
            let textLength = raw.count
            let markerLength = textLength - token.text.count
            let textRangeStart = lineStart + markerLength
            let textRangeEnd = lineStart + textLength
            annotated.append(
                AnnotatedLine(
                    token: token,
                    textRange: textRangeStart..<textRangeEnd
                )
            )
            // +1 for the newline separator, except after the final line.
            lineStart += textLength + (idx < lines.count - 1 ? 1 : 0)
        }

        var cursor = 0
        var output: [EntryContentBlock] = []
        while cursor < annotated.count {
            let line = annotated[cursor]
            if line.token.kind == .paragraph {
                output.append(
                    .paragraph(text: line.token.text, textRange: line.textRange)
                )
                cursor += 1
            } else {
                let (block, next) = parseList(
                    lines: annotated,
                    from: cursor,
                    level: line.token.indent
                )
                output.append(.list(block))
                cursor = next
            }
        }
        return output
    }

    /// Classifies a single line. Called by the state layer per-keystroke on
    /// the cursor line so the dock can offer the right indent/outdent state.
    public static func tokenize(line: String) -> EntryLineToken {
        var leadingSpaces = 0
        for ch in line {
            if ch == " " { leadingSpaces += 1 } else { break }
        }
        let indent = leadingSpaces / 2
        let trimmed = String(line.dropFirst(leadingSpaces))

        if trimmed.hasPrefix("- ") {
            return EntryLineToken(
                indent: indent,
                kind: .bullet,
                text: String(trimmed.dropFirst(2))
            )
        }
        if let (text, number) = stripNumberedPrefix(trimmed) {
            return EntryLineToken(
                indent: indent,
                kind: .numbered,
                text: text,
                number: number
            )
        }
        return EntryLineToken(indent: 0, kind: .paragraph, text: line)
    }

    // MARK: - Private

    private struct AnnotatedLine {
        let token: EntryLineToken
        let textRange: Range<Int>
    }

    private static func parseList(
        lines: [AnnotatedLine],
        from start: Int,
        level: Int
    ) -> (EntryListBlock, Int) {
        guard let targetKind = lines[start].token.kind.listKind else {
            return (EntryListBlock(kind: .bullet, items: []), start + 1)
        }

        var items: [EntryListItem] = []
        var cursor = start

        while cursor < lines.count {
            let line = lines[cursor]
            if line.token.kind == .paragraph { break }
            if line.token.indent < level { break }
            if line.token.indent == level && line.token.kind != targetKind.tokenKind {
                break
            }
            if line.token.indent > level {
                let (childBlock, next) = parseList(
                    lines: lines,
                    from: cursor,
                    level: line.token.indent
                )
                if let last = items.popLast() {
                    items.append(
                        EntryListItem(
                            text: last.text,
                            textRange: last.textRange,
                            children: last.children + [childBlock]
                        )
                    )
                } else {
                    items.append(
                        EntryListItem(text: "", textRange: 0..<0, children: [childBlock])
                    )
                }
                cursor = next
                continue
            }
            items.append(
                EntryListItem(
                    text: line.token.text,
                    textRange: line.textRange,
                    children: []
                )
            )
            cursor += 1
        }

        let blockKind: EntryListBlock.Kind = targetKind == .bullet ? .bullet : .numbered
        return (EntryListBlock(kind: blockKind, items: items), cursor)
    }

    private static func stripNumberedPrefix(_ string: String) -> (text: String, number: Int)? {
        var digitEnd = string.startIndex
        var digitCount = 0
        for idx in string.indices {
            let ch = string[idx]
            if ch.isNumber {
                digitEnd = string.index(after: idx)
                digitCount += 1
            } else {
                break
            }
        }
        guard digitCount > 0, digitEnd < string.endIndex, string[digitEnd] == "." else {
            return nil
        }
        let afterDot = string.index(after: digitEnd)
        guard afterDot < string.endIndex, string[afterDot] == " " else {
            return nil
        }
        let textStart = string.index(after: afterDot)
        let number = Int(string[string.startIndex..<digitEnd]) ?? 1
        return (String(string[textStart...]), number)
    }
}

private extension EntryLineToken.Kind {
    var listKind: ListKind? {
        switch self {
        case .paragraph: nil
        case .bullet: .bullet
        case .numbered: .numbered
        }
    }
}

private enum ListKind {
    case bullet
    case numbered

    var tokenKind: EntryLineToken.Kind {
        switch self {
        case .bullet: .bullet
        case .numbered: .numbered
        }
    }
}
