import Foundation
import SwiftUI
import CoreKit

/// Generates Markdown and PDF exports from `EntrySnapshot` arrays.
/// Writes to the app's temporary directory and returns the file URL so
/// callers can hand it to a share sheet.
public struct ExportService: Sendable {
    public init() {}

    // MARK: - Markdown

    public func exportMarkdown(
        entries: [EntrySnapshot],
        range: ClosedRange<Date>? = nil,
        locale: Locale = .autoupdatingCurrent
    ) throws -> URL {
        let text = Self.renderMarkdown(entries: entries, range: range, locale: locale)
        let url = Self.temporaryURL(extension: "md", label: "mira-export")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func renderMarkdown(
        entries: [EntrySnapshot],
        range: ClosedRange<Date>?,
        locale: Locale
    ) -> String {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.dateStyle = .full
        dayFormatter.timeStyle = .none

        var lines: [String] = []
        lines.append("# Journal")
        if let range {
            let intervalFormatter = DateIntervalFormatter()
            intervalFormatter.locale = locale
            intervalFormatter.dateStyle = .medium
            intervalFormatter.timeStyle = .none
            lines.append("_\(intervalFormatter.string(from: range.lowerBound, to: range.upperBound) ?? "")_")
        }
        lines.append("")

        for entry in sorted {
            lines.append("## \(dayFormatter.string(from: entry.createdAt))")
            var meta: [String] = []
            if let mood = entry.mood {
                meta.append("mood: \(mood.rawValue)")
            }
            if !entry.tags.isEmpty {
                meta.append("tags: \(entry.tags.joined(separator: ", "))")
            }
            if !meta.isEmpty {
                lines.append("_\(meta.joined(separator: " · "))_")
            }
            lines.append("")
            lines.append(entry.plainContent)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF

    @MainActor
    public func exportPDF(
        entries: [EntrySnapshot],
        template: PDFTemplate = .minimal,
        range: ClosedRange<Date>? = nil,
        locale: Locale = .autoupdatingCurrent
    ) throws -> URL {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let view = pageView(template: template, entries: sorted, range: range, locale: locale)
        let renderer = ImageRenderer(content: view.frame(width: 612)) // US Letter @ 72 dpi
        renderer.proposedSize = .init(width: 612, height: nil)

        let url = Self.temporaryURL(extension: "pdf", label: "mira-export-\(template.rawValue)")
        var success = false
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            success = true
        }
        guard success else {
            throw NSError(
                domain: "ExportService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render PDF."]
            )
        }
        return url
    }

    @MainActor @ViewBuilder
    private func pageView(
        template: PDFTemplate,
        entries: [EntrySnapshot],
        range: ClosedRange<Date>?,
        locale: Locale
    ) -> some View {
        switch template {
        case .minimal:
            MinimalPageView(entries: entries, range: range, locale: locale)
        case .editorial:
            EditorialPageView(entries: entries, range: range, locale: locale)
        case .notebook:
            NotebookPageView(entries: entries, range: range, locale: locale)
        }
    }

    // MARK: - Helpers

    static func temporaryURL(extension ext: String, label: String) -> URL {
        let name = "\(label)-\(Int(Date.now.timeIntervalSince1970)).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}

// MARK: - Template page views
//
// Each template is a self-contained SwiftUI view sized to US Letter
// width (612pt @ 72dpi). The templates intentionally don't share a
// base struct — divergence is the point. Add a new template by adding
// a case to PDFTemplate, the dispatch in pageView(template:), and a
// view here.

/// Sans-serif, generous whitespace, no decorative elements. Free
/// users always get this template; Pro users can pick it from the
/// sheet.
private struct MinimalPageView: View {
    let entries: [EntrySnapshot]
    let range: ClosedRange<Date>?
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal").font(.largeTitle.weight(.semibold))
            if let range {
                Text(range.lowerBound, format: .dateTime.day().month().year())
                +
                Text(" — ")
                +
                Text(range.upperBound, format: .dateTime.day().month().year())
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.createdAt, format: .dateTime.day().month(.wide).year())
                        .font(.headline)
                    if let mood = entry.mood {
                        Text("mood: \(mood.rawValue)").font(.caption).foregroundStyle(.secondary)
                    }
                    if !entry.tags.isEmpty {
                        Text("tags: \(entry.tags.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.content).font(.body)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Serif-led typography, drop-cap accents, rule dividers between
/// entries. Reads like an essay collection.
private struct EditorialPageView: View {
    let entries: [EntrySnapshot]
    let range: ClosedRange<Date>?
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Journal")
                    .font(.system(size: 44, weight: .bold, design: .serif))
                if let range {
                    (
                        Text(range.lowerBound, format: .dateTime.day().month(.wide).year())
                        + Text(" — ")
                        + Text(range.upperBound, format: .dateTime.day().month(.wide).year())
                    )
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 28)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                        .background(Color.primary.opacity(0.15))
                        .padding(.vertical, 18)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.createdAt, format: .dateTime.day().month(.wide).year())
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .textCase(.uppercase)
                        .tracking(1.2)

                    if let mood = entry.mood, !entry.tags.isEmpty {
                        Text("mood \(mood.rawValue) · \(entry.tags.joined(separator: ", "))")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.secondary)
                    } else if let mood = entry.mood {
                        Text("mood \(mood.rawValue)")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.secondary)
                    } else if !entry.tags.isEmpty {
                        Text(entry.tags.joined(separator: ", "))
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    Text(entry.content)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .lineSpacing(4)
                }
            }
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Faint paper rules underneath serif body text. Casual, intended for
/// printing. The lines render via a `Canvas` overlay so they hug the
/// text without affecting layout.
private struct NotebookPageView: View {
    let entries: [EntrySnapshot]
    let range: ClosedRange<Date>?
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primary.opacity(0.85))
                if let range {
                    (
                        Text(range.lowerBound, format: .dateTime.day().month().year())
                        + Text(" — ")
                        + Text(range.upperBound, format: .dateTime.day().month().year())
                    )
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                }
            }

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.createdAt, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                        Spacer()
                        if let mood = entry.mood {
                            Text("☼ \(mood.rawValue)")
                                .font(.system(size: 11, weight: .regular, design: .serif))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(entry.content)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .background(
                            // Repeating ruled lines. Spacing matches
                            // body line height (~21pt) so each row
                            // sits on its rule.
                            GeometryReader { proxy in
                                Path { p in
                                    let step: CGFloat = 21
                                    var y: CGFloat = step
                                    while y < proxy.size.height {
                                        p.move(to: CGPoint(x: 0, y: y))
                                        p.addLine(to: CGPoint(x: proxy.size.width, y: y))
                                        y += step
                                    }
                                }
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                            }
                        )
                    if !entry.tags.isEmpty {
                        Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
