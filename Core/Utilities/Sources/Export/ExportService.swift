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
        range: ClosedRange<Date>? = nil,
        locale: Locale = .autoupdatingCurrent
    ) throws -> URL {
        let page = ExportPageView(
            entries: entries.sorted { $0.createdAt < $1.createdAt },
            range: range,
            locale: locale
        )
        let renderer = ImageRenderer(content: page.frame(width: 612)) // US Letter @ 72 dpi
        renderer.proposedSize = .init(width: 612, height: nil)

        let url = Self.temporaryURL(extension: "pdf", label: "mira-export")
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

    // MARK: - Helpers

    static func temporaryURL(extension ext: String, label: String) -> URL {
        let name = "\(label)-\(Int(Date.now.timeIntervalSince1970)).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}

/// Minimal SwiftUI page used as the PDF canvas. Kept separate so
/// ExportService stays free of view bodies.
private struct ExportPageView: View {
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
