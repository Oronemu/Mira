import Foundation
import CoreKit

/// Parses a markdown body into an `AttributedString` carrying Mira's domain
/// attributes (bold/italic + heading sizes). The result is what
/// `MarkdownImporter` hands to `EntrySnapshot(content:)` — so imported
/// markdown files render with proper formatting instead of literal
/// `**stars**` and `## hashes`.
///
/// Block-level: `#`/`##`/`###` headings → font size + bold. List markers
/// (`- `, `1. `) and other line prefixes pass through verbatim because
/// `EntryContentParser` reads them at render time.
///
/// Inline: `**bold**`, `__bold__`, `*italic*`, `_italic_`. Mid-word `_`
/// (`snake_case`) is left alone. Strikethrough, inline code, fenced code
/// blocks, blockquotes, links and images are intentionally not parsed —
/// the domain has no attribute to map them to, so they pass through as
/// plain text.
public enum MarkdownToAttributedString {
    public static func parse(_ body: String) -> AttributedString {
        var output = AttributedString()
        let lines = body.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            output.append(parseLine(line))
            if index != lines.count - 1 {
                output.append(AttributedString("\n"))
            }
        }
        return output
    }

    // MARK: - Block: headings

    private static func parseLine(_ line: String) -> AttributedString {
        guard let (level, headingBody) = headingPrefix(line) else {
            return parseInline(line)
        }
        var attr = parseInline(headingBody)
        let range = attr.startIndex..<attr.endIndex
        guard range.lowerBound < range.upperBound else { return attr }
        attr[range][EntryFontSizeAttribute.self] = headingSize(level)
        attr[range][EntryBoldAttribute.self] = true
        return attr
    }

    private static func headingPrefix(_ line: String) -> (Int, String)? {
        guard line.hasPrefix("#") else { return nil }
        var hashCount = 0
        for ch in line {
            if ch == "#" {
                hashCount += 1
                if hashCount > 3 { return nil }
            } else {
                break
            }
        }
        guard (1...3).contains(hashCount) else { return nil }
        let after = line.index(line.startIndex, offsetBy: hashCount)
        guard after < line.endIndex, line[after] == " " else { return nil }
        let bodyStart = line.index(after: after)
        return (hashCount, String(line[bodyStart...]))
    }

    private static func headingSize(_ level: Int) -> EntryFontSize {
        switch level {
        case 1: .extraLarge
        case 2: .large
        default: .regular
        }
    }

    // MARK: - Inline emphasis

    /// Tokenises a single line into runs and emits an `AttributedString`
    /// with bold/italic toggled per matched pair. Unmatched markers leak
    /// the toggle to end-of-line — that's a deliberate trade-off versus
    /// the cost of a lookahead pass; the importer is best-effort.
    private static func parseInline(_ line: String) -> AttributedString {
        var output = AttributedString()
        var bold = false
        var italic = false
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            var attr = AttributedString(buffer)
            let range = attr.startIndex..<attr.endIndex
            if bold { attr[range][EntryBoldAttribute.self] = true }
            if italic { attr[range][EntryItalicAttribute.self] = true }
            output.append(attr)
            buffer.removeAll(keepingCapacity: true)
        }

        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]

            // Strong: `**` or `__`. Treat both characters as identical
            // pairs — we don't try to balance mismatched openers/closers.
            if (c == "*" || c == "_"),
               i + 1 < chars.count, chars[i + 1] == c {
                flush()
                bold.toggle()
                i += 2
                continue
            }

            // Emphasis: a lone `*` or `_`. Skip mid-word `_` so common
            // identifiers (`snake_case`, `__init__`) don't render italic.
            if c == "*" || c == "_" {
                let prevIsWord = i > 0 && isWordChar(chars[i - 1])
                let nextIsWord = i + 1 < chars.count && isWordChar(chars[i + 1])
                if c == "_" && prevIsWord && nextIsWord {
                    buffer.append(c)
                    i += 1
                    continue
                }
                flush()
                italic.toggle()
                i += 1
                continue
            }

            buffer.append(c)
            i += 1
        }
        flush()
        return output
    }

    private static func isWordChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber
    }
}
