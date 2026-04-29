import Foundation

// MARK: - Custom AttributedString keys
//
// We keep formatting (font family/size, colour, bold/italic/underline) as
// custom domain attributes rather than reusing SwiftUI's `.font`/`.foregroundColor`.
// Reasons:
//   • Domain types (EntryFontFamily, EntryFontSize, EntryTextColor) are
//     Codable — built-in attributes are not.
//   • The renderer resolves our attributes into concrete SwiftUI `Font`/
//     `Color` at draw time, keeping the on-disk representation device- and
//     mode-independent.
//   • Persistence can walk `content.runs` and round-trip without loss.

public enum EntryFontFamilyAttribute: AttributedStringKey, Sendable {
    public typealias Value = EntryFontFamily
    public static let name = "com.mira.fontFamily"
}

public enum EntryFontSizeAttribute: AttributedStringKey, Sendable {
    public typealias Value = EntryFontSize
    public static let name = "com.mira.fontSize"
}

public enum EntryTextColorAttribute: AttributedStringKey, Sendable {
    public typealias Value = EntryTextColor
    public static let name = "com.mira.textColor"
}

public enum EntryBoldAttribute: AttributedStringKey, Sendable {
    public typealias Value = Bool
    public static let name = "com.mira.bold"
}

public enum EntryItalicAttribute: AttributedStringKey, Sendable {
    public typealias Value = Bool
    public static let name = "com.mira.italic"
}

public enum EntryUnderlineAttribute: AttributedStringKey, Sendable {
    public typealias Value = Bool
    public static let name = "com.mira.underline"
}

// MARK: - Attribute scope

/// Scope bundling the domain attributes together so callers can read/write
/// them via `attr.fontFamily` / `container.fontSize` etc.
public struct EntryAttributeScope: AttributeScope {
    public let fontFamily: EntryFontFamilyAttribute
    public let fontSize: EntryFontSizeAttribute
    public let textColor: EntryTextColorAttribute
    public let bold: EntryBoldAttribute
    public let italic: EntryItalicAttribute
    public let underline: EntryUnderlineAttribute
    public let foundation: AttributeScopes.FoundationAttributes
}

public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<EntryAttributeScope, T>) -> T {
        self[T.self]
    }
}

// MARK: - Serialization

/// Codec that serialises `AttributedString` to/from a compact JSON payload
/// keyed by character offsets. Runs carrying no domain attributes are
/// omitted — the plain text alone is enough to reconstruct them.
public enum EntryContentCodec {

    private struct SerializedRun: Codable, Sendable {
        let startChar: Int
        let endChar: Int
        var fontFamily: EntryFontFamily?
        var fontSize: EntryFontSize?
        var textColor: EntryTextColor?
        var bold: Bool?
        var italic: Bool?
        var underline: Bool?
    }

    private struct SerializedContent: Codable, Sendable {
        let plainText: String
        let runs: [SerializedRun]
    }

    public static func encode(_ content: AttributedString) throws -> Data {
        var serialisedRuns: [SerializedRun] = []
        var charCursor = 0
        for run in content.runs {
            let slice = content[run.range]
            let sliceLength = slice.characters.count
            defer { charCursor += sliceLength }

            let family = run[EntryFontFamilyAttribute.self]
            let size = run[EntryFontSizeAttribute.self]
            let color = run[EntryTextColorAttribute.self]
            let bold = run[EntryBoldAttribute.self]
            let italic = run[EntryItalicAttribute.self]
            let underline = run[EntryUnderlineAttribute.self]

            // Skip runs that carry no domain attributes.
            guard family != nil || size != nil || color != nil
                    || bold == true || italic == true || underline == true else {
                continue
            }

            serialisedRuns.append(
                SerializedRun(
                    startChar: charCursor,
                    endChar: charCursor + sliceLength,
                    fontFamily: family,
                    fontSize: size,
                    textColor: color,
                    bold: bold == true ? true : nil,
                    italic: italic == true ? true : nil,
                    underline: underline == true ? true : nil
                )
            )
        }
        let payload = SerializedContent(
            plainText: String(content.characters),
            runs: serialisedRuns
        )
        return try JSONEncoder().encode(payload)
    }

    public static func decode(_ data: Data) throws -> AttributedString {
        let payload = try JSONDecoder().decode(SerializedContent.self, from: data)
        var attr = AttributedString(payload.plainText)
        let chars = attr.characters
        for run in payload.runs {
            guard run.startChar >= 0,
                  run.endChar <= chars.count,
                  run.startChar < run.endChar else { continue }
            let start = chars.index(chars.startIndex, offsetBy: run.startChar)
            let end = chars.index(chars.startIndex, offsetBy: run.endChar)
            let range = start..<end
            if let family = run.fontFamily {
                attr[range][EntryFontFamilyAttribute.self] = family
            }
            if let size = run.fontSize {
                attr[range][EntryFontSizeAttribute.self] = size
            }
            if let color = run.textColor {
                attr[range][EntryTextColorAttribute.self] = color
            }
            if run.bold == true {
                attr[range][EntryBoldAttribute.self] = true
            }
            if run.italic == true {
                attr[range][EntryItalicAttribute.self] = true
            }
            if run.underline == true {
                attr[range][EntryUnderlineAttribute.self] = true
            }
        }
        return attr
    }

    // MARK: Convenience builders

    /// Wraps a plain string into an AttributedString and applies a uniform
    /// style across its entirety. Used by the persistence migration that
    /// converts legacy `String` + `EntryTextStyle` entries into the new
    /// AttributedString model.
    public static func attributedString(
        from plain: String,
        applying style: EntryTextStyle
    ) -> AttributedString {
        var attr = AttributedString(plain)
        if !plain.isEmpty {
            let full = attr.startIndex..<attr.endIndex
            attr[full][EntryFontFamilyAttribute.self] = style.family
            attr[full][EntryFontSizeAttribute.self] = style.size
            attr[full][EntryTextColorAttribute.self] = style.color
        }
        return attr
    }
}
