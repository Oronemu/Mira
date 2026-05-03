import SwiftUI
import UniformTypeIdentifiers
import CoreKit
import DesignSystem
import Utilities

/// Pro feature — bulk-import journal entries from Markdown files.
/// Uses SwiftUI's document picker so the user can grab a single Mira
/// export, a folder of `.md` files (Bear / Obsidian), or any mix.
public struct ImportSettingsView: View {
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.analyticsService) private var analyticsService

    @State private var showingPicker = false
    @State private var picked: [URL] = []
    @State private var phase: Phase = .idle
    @State private var lastResult: ImportSummary?

    private enum Phase: Equatable {
        case idle
        case parsing
        case writing(progress: Double)
        case done
    }

    private struct ImportSummary: Equatable {
        let imported: Int
        let errors: [String]
    }

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsHero(
                        title: "Import",
                        subtitle: "Bring older entries into Mira"
                    )

                    formatsCard
                    pickerCard
                    if !picked.isEmpty { selectionList }
                    if let summary = lastResult { resultCard(summary) }

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Import")
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText, .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): picked = urls
            case .failure: picked = []
            }
        }
    }

    // MARK: - Cards

    private var formatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported")
                .eyebrowStyle()
            VStack(alignment: .leading, spacing: 4) {
                Text("• Mira's own Markdown export")
                Text("• One Markdown file per entry (Bear, Obsidian, manual exports)")
                Text("• YAML frontmatter — date, mood, tags — when present")
            }
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var pickerCard: some View {
        Button {
            picked = []
            lastResult = nil
            showingPicker = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: 4).opacity(0.18)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Choose Markdown files"))
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(String(localized: "You can pick multiple at once."))
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(phase != .idle && phase != .done)
    }

    private var selectionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected").eyebrowStyle()
            ForEach(picked, id: \.self) { url in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(MiraTypography.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(buttonTitle) {
                    Task { await runImport() }
                }
                .disabled(phase == .parsing || isWriting)

                if isWriting {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var isWriting: Bool {
        if case .writing = phase { return true } else { return false }
    }

    private var buttonTitle: String {
        switch phase {
        case .idle, .done: return String(localized: "Import")
        case .parsing: return String(localized: "Reading…")
        case .writing(let p): return String(format: String(localized: "Importing %.0f%%"), p * 100)
        }
    }

    private func resultCard(_ summary: ImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "Imported %lld entries"), summary.imported))
                .font(MiraTypography.headline)
            if !summary.errors.isEmpty {
                Text(String(localized: "Some files were skipped:"))
                    .font(MiraTypography.caption)
                    .foregroundStyle(.secondary)
                ForEach(summary.errors, id: \.self) { msg in
                    Text("• \(msg)")
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Action

    private func runImport() async {
        phase = .parsing
        let urls = picked
        let parseResult: MarkdownImporter.Result
        do {
            parseResult = try MarkdownImporter().parse(fileURLs: urls)
        } catch {
            lastResult = ImportSummary(imported: 0, errors: [error.localizedDescription])
            phase = .done
            return
        }

        let total = max(1, parseResult.entries.count)
        var written = 0
        for (index, entry) in parseResult.entries.enumerated() {
            do {
                try await entryRepository.save(entry)
                written += 1
            } catch {
                // Per-entry write failure — record but don't abort the
                // whole batch; users have already approved the import.
                continue
            }
            phase = .writing(progress: Double(index + 1) / Double(total))
        }

        analyticsService.log(
            event: "import_markdown",
            parameters: [
                "files": .int(urls.count),
                "entries_imported": .int(written),
                "entries_skipped": .int(parseResult.entries.count - written),
            ]
        )

        lastResult = ImportSummary(imported: written, errors: parseResult.errors)
        picked = []
        phase = .done
    }
}
