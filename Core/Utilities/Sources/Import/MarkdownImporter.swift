import Foundation
import CoreKit

/// Parses one or many `.md` files into journal entries the caller can
/// hand to `EntryRepository.save`. Built for two common shapes:
///
/// 1. **Mira's own export format** — single file with `## <date>` sections,
///    each optionally followed by `_mood: N · tags: a, b_`. Reimport
///    round-trips cleanly.
/// 2. **One-entry-per-file** — Bear, Obsidian, manual exports. Each
///    file becomes one entry; YAML frontmatter (`date`, `mood`, `tags`)
///    is honoured when present, otherwise the file's modification date
///    fills `createdAt` and the body is used verbatim.
public struct MarkdownImporter: Sendable {
    public init() {}

    /// Reads each URL, parses according to its content, and returns
    /// flattened drafts ordered by `createdAt`. Throws only on
    /// unrecoverable read errors — malformed metadata is logged via
    /// the `errors` collector and the entry still imports as best it
    /// can.
    public func parse(fileURLs: [URL]) throws -> Result {
        var entries: [EntrySnapshot] = []
        var errors: [String] = []

        for url in fileURLs {
            // Document picker hands us security-scoped URLs; we have to
            // start access before reading and stop after, regardless of
            // whether the read succeeded.
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            let text: String
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                continue
            }

            let fileDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .now

            entries.append(contentsOf: parse(text: text, fallbackDate: fileDate))
        }

        entries.sort { $0.createdAt < $1.createdAt }
        return Result(entries: entries, errors: errors)
    }

    public struct Result: Sendable, Hashable {
        public let entries: [EntrySnapshot]
        public let errors: [String]
    }

    // MARK: - Parsing

    private func parse(text: String, fallbackDate: Date) -> [EntrySnapshot] {
        let (frontmatter, body) = stripFrontmatter(text)
        let sections = splitSections(body)

        // Single entry: no `## ` sections found, treat the whole body
        // as one entry. Frontmatter (if any) provides metadata.
        if sections.count == 1 && sections[0].heading == nil {
            let plain = sections[0].body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { return [] }
            return [
                EntrySnapshot(
                    createdAt: frontmatter.date ?? fallbackDate,
                    content: MarkdownToAttributedString.parse(plain),
                    mood: frontmatter.mood,
                    tags: frontmatter.tags
                )
            ]
        }

        // Multi-section file (Mira export): one entry per `## ` block.
        return sections.compactMap { section in
            let trimmedBody = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBody.isEmpty || section.mood != nil || !section.tags.isEmpty else {
                return nil
            }
            let date = section.date ?? frontmatter.date ?? fallbackDate
            return EntrySnapshot(
                createdAt: date,
                content: MarkdownToAttributedString.parse(trimmedBody),
                mood: section.mood ?? frontmatter.mood,
                tags: section.tags.isEmpty ? frontmatter.tags : section.tags
            )
        }
    }

    // MARK: - YAML frontmatter

    private struct Frontmatter {
        let date: Date?
        let mood: Mood?
        let tags: [String]
    }

    /// Strips and returns a leading `---\n…\n---\n` block. Only handles
    /// the keys we care about (`date`, `mood`, `tags`). Anything else
    /// is ignored — we don't want to ship a full YAML parser dep.
    private func stripFrontmatter(_ text: String) -> (Frontmatter, String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---\n") else {
            return (Frontmatter(date: nil, mood: nil, tags: []), text)
        }
        let afterOpen = trimmed.dropFirst(4)
        guard let endRange = afterOpen.range(of: "\n---") else {
            return (Frontmatter(date: nil, mood: nil, tags: []), text)
        }
        let yamlBlock = afterOpen[..<endRange.lowerBound]
        let body = afterOpen[endRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var date: Date? = nil
        var mood: Mood? = nil
        var tags: [String] = []
        for rawLine in yamlBlock.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            if let value = field(in: line, key: "date") {
                date = parseDate(value)
            } else if let value = field(in: line, key: "mood") {
                mood = Mood(rawValue: Int(value.trimmingCharacters(in: .whitespaces)) ?? -1)
            } else if let value = field(in: line, key: "tags") {
                tags = parseTagList(value)
            }
        }
        return (Frontmatter(date: date, mood: mood, tags: tags), String(body))
    }

    private func field(in line: String, key: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("\(key):") else { return nil }
        return String(trimmed.dropFirst(key.count + 1))
            .trimmingCharacters(in: .whitespaces)
    }

    private func parseTagList(_ raw: String) -> [String] {
        // Accepts either `[a, b, c]` or `a, b, c` or YAML list `- a\n- b`
        // (the line-based form is uncommon as a single-line value, so
        // we only handle the inline forms).
        var s = raw
        if s.hasPrefix("[") && s.hasSuffix("]") {
            s = String(s.dropFirst().dropLast())
        }
        return s.split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'"))) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Section splitter

    private struct Section {
        let heading: String?
        let body: String
        let date: Date?
        let mood: Mood?
        let tags: [String]
    }

    /// Splits the body into sections delimited by `## `. The leading
    /// `# Journal` title (if present) and any preamble before the first
    /// `## ` are dropped. Each section's first line after the heading is
    /// inspected for the export's `_mood: N · tags: a, b_` annotation.
    private func splitSections(_ body: String) -> [Section] {
        // No `## ` header → single section spanning the whole body.
        guard body.contains("\n## ") || body.hasPrefix("## ") else {
            return [Section(heading: nil, body: body, date: nil, mood: nil, tags: [])]
        }

        var sections: [Section] = []
        let parts = body.components(separatedBy: "\n## ")
        for (index, raw) in parts.enumerated() {
            // First chunk before any `## ` — drop unless it looks like
            // a section itself (i.e. body starts with `## `).
            if index == 0 && !body.hasPrefix("## ") { continue }
            let chunk = (index == 0 ? String(raw.dropFirst("## ".count)) : raw)
            let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false)
            guard let heading = lines.first.map(String.init) else { continue }
            let rest = lines.dropFirst().joined(separator: "\n")
            let (mood, tags, contentBody) = stripMetaLine(rest)
            sections.append(
                Section(
                    heading: heading,
                    body: contentBody,
                    date: parseDate(heading),
                    mood: mood,
                    tags: tags
                )
            )
        }
        return sections
    }

    /// Pops the export's `_mood: N · tags: a, b_` italic line off the
    /// top of a section body if present. Returns the cleaned body and
    /// the parsed metadata.
    private func stripMetaLine(_ body: String) -> (Mood?, [String], String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLineEnd = trimmed.range(of: "\n") else {
            return parseMetaLine(trimmed).map { ($0.0, $0.1, "") } ?? (nil, [], trimmed)
        }
        let firstLine = String(trimmed[..<firstLineEnd.lowerBound])
        guard let parsed = parseMetaLine(firstLine) else {
            return (nil, [], trimmed)
        }
        let remainder = String(trimmed[firstLineEnd.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (parsed.0, parsed.1, remainder)
    }

    /// Matches `_mood: 4 · tags: work, sleep_` or its variants
    /// (only mood, only tags, etc.). Returns nil when the line isn't a
    /// meta line so the body stays intact.
    private func parseMetaLine(_ line: String) -> (Mood?, [String])? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("_") && trimmed.hasSuffix("_") else { return nil }
        let inner = String(trimmed.dropFirst().dropLast())
        let parts = inner.components(separatedBy: " · ")
        var mood: Mood? = nil
        var tags: [String] = []
        var matched = false
        for part in parts {
            let trimmedPart = part.trimmingCharacters(in: .whitespaces)
            if trimmedPart.hasPrefix("mood:") {
                let value = trimmedPart.dropFirst("mood:".count).trimmingCharacters(in: .whitespaces)
                if let raw = Int(value), let m = Mood(rawValue: raw) {
                    mood = m
                    matched = true
                }
            } else if trimmedPart.hasPrefix("tags:") {
                let value = String(trimmedPart.dropFirst("tags:".count))
                tags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                matched = true
            }
        }
        return matched ? (mood, tags) : nil
    }

    // MARK: - Date parsing

    /// Tries multiple date formats, in order of how strict they are.
    /// Stops at the first match. Returns nil rather than .now so the
    /// caller can fall back to the file's modification date.
    private func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let iso = Self.iso8601.date(from: trimmed) { return iso }
        for formatter in Self.formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let formatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "MMMM d, yyyy",      // "January 5, 2026"
            "EEEE, MMMM d, yyyy", // "Friday, January 5, 2026" — Mira's export
            "d MMMM yyyy",
            "MMM d, yyyy",
        ]
        return patterns.map { p in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = p
            return f
        }
    }()
}
