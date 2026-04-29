import SwiftUI
import CoreKit

/// Renders an entry body — given as `AttributedString` with our custom
/// per-range attributes — for the reading canvas. Parsing is done on the
/// plain-text view; each block/item carries a character-offset range into
/// the plain text, so the renderer pulls the matching `AttributedString`
/// slice directly and SwiftUI preserves all run-level attributes.
public struct EntryContentRenderer: View {
    private let source: AttributedString
    private let resolved: AttributedString
    private let blocks: [EntryContentBlock]

    public init(content: AttributedString) {
        self.source = content
        let resolved = content.resolvedForDisplay()
        self.resolved = resolved
        self.blocks = EntryContentParser.parse(String(resolved.characters))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func render(_ block: EntryContentBlock) -> some View {
        switch block {
        case .paragraph(_, let range):
            paragraphText(range: range)
        case .list(let list):
            EntryListBlockView(block: list, source: resolved)
        }
    }

    private func paragraphText(range: Range<Int>) -> some View {
        let slice = slice(resolved, range: range)
        return Text(slice)
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - List renderer

private struct EntryListBlockView: View {
    let block: EntryListBlock
    let source: AttributedString

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(marker(for: index))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 22, alignment: .trailing)
                        Text(slice(source, range: item.textRange))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                        EntryListBlockView(block: child, source: source)
                            .padding(.leading, 28)
                    }
                }
            }
        }
    }

    private func marker(for index: Int) -> String {
        switch block.kind {
        case .bullet: "•"
        case .numbered: "\(index + 1)."
        }
    }
}

// MARK: - Slice helper

private func slice(_ source: AttributedString, range: Range<Int>) -> AttributedString {
    let characters = source.characters
    let total = characters.count
    let lower = max(0, min(range.lowerBound, total))
    let upper = max(lower, min(range.upperBound, total))
    let startIdx = characters.index(characters.startIndex, offsetBy: lower)
    let endIdx = characters.index(characters.startIndex, offsetBy: upper)
    return AttributedString(source[startIdx..<endIdx])
}

