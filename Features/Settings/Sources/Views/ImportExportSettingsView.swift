import SwiftUI
import UniformTypeIdentifiers
import CoreKit
import Utilities
import AIKit
import DesignSystem

/// Combined Import & Export screen. Replaces the two separate
/// settings entries with one destination so the user sees data
/// portability in one place. Export is free (PDF stays Pro-gated as
/// before); Import is Pro across the board — free users see a single
/// "Unlock Pro" card in place of the picker.
public struct ImportExportSettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    // Export state
    @State private var settingsState: SettingsState?
    @State private var exportURL: IdentifiableURL?
    @State private var isExporting: Bool = false
    @State private var activeKind: ExportKind?
    @State private var showingTemplatePicker: Bool = false

    // Import state
    @State private var showingImporter = false
    @State private var picked: [URL] = []
    @State private var importPhase: ImportPhase = .idle
    @State private var importResult: ImportSummary?

    // Shared
    @State private var status: SubscriptionStatus = .unknown

    private enum ExportKind: Hashable { case markdown, pdf }

    private enum ImportPhase: Equatable {
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

            Group {
                if let settingsState {
                    content(state: settingsState)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Import & export")
        .task {
            if settingsState == nil {
                settingsState = SettingsState(
                    service: aiService,
                    entryRepository: entryRepository,
                    insightRepository: insightRepository,
                    coordinator: coordinator,
                    analyticsService: analyticsService,
                    crashReporter: crashReporter
                )
            }
        }
        .task {
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
        .sheet(isPresented: $showingTemplatePicker) {
            if let settingsState {
                PDFTemplatePickerSheet { template in
                    showingTemplatePicker = false
                    runExport(kind: .pdf, template: template, state: settingsState)
                } onCancel: {
                    showingTemplatePicker = false
                }
                .presentationDetents([.medium, .large])
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText, .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): picked = urls
            case .failure: picked = []
            }
        }
    }

    private func content(state: SettingsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHero(
                    title: "Import & export",
                    subtitle: "Take entries in, take entries out"
                )

                exportSection(state: state)

                importSection

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Export

    private func exportSection(state: SettingsState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export").eyebrowStyle().padding(.leading, 4)

            VStack(spacing: 10) {
                formatCard(
                    icon: "doc.text",
                    title: "Markdown",
                    subtitle: "Plain text with a YAML front-matter per entry. Great for Obsidian, Bear, or any text editor.",
                    moodLevel: 2,
                    kind: .markdown
                ) {
                    runExport(kind: .markdown, state: state)
                }

                formatCard(
                    icon: "doc.richtext",
                    title: "PDF",
                    subtitle: "Formatted, printable copy with your mood and tags preserved.",
                    moodLevel: 4,
                    kind: .pdf,
                    showsProBadge: !status.isPro
                ) {
                    if status.isPro {
                        showingTemplatePicker = true
                    } else {
                        paywallPresenter.present(.feature(.pdfExportTemplates))
                    }
                }
            }
            .disabled(isExporting)

            Text("Mira writes the file to a temporary location and hands it to the share sheet so you can move it wherever you like.")
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText)
                .lineSpacing(2)
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
    }

    private func formatCard(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        moodLevel: Int,
        kind: ExportKind,
        showsProBadge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(0.18)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText)
                        if showsProBadge { ProBadge() }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Group {
                    if activeKind == kind && isExporting {
                        ProgressView().controlSize(.small)
                    } else if showsProBadge {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MiraPalette.primaryText.opacity(0.75))
                    }
                }
                .padding(.top, 12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func runExport(kind: ExportKind, template: PDFTemplate = .minimal, state: SettingsState) {
        guard !isExporting else { return }
        isExporting = true
        activeKind = kind
        Task {
            let url: URL?
            switch kind {
            case .markdown: url = await state.exportMarkdown()
            case .pdf:      url = await state.exportPDF(template: template)
            }
            if let url { exportURL = IdentifiableURL(url: url) }
            isExporting = false
            activeKind = nil
        }
    }

    // MARK: - Import

    @ViewBuilder
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import").eyebrowStyle().padding(.leading, 4)

            if status.isPro {
                proImportContent
            } else {
                lockedImportCard
            }
        }
    }

    private var lockedImportCard: some View {
        Button {
            paywallPresenter.present(.feature(.importers))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: 4).opacity(0.18)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(String(localized: "Bring older entries in"))
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText)
                        ProBadge()
                    }
                    Text(String(localized: "Import from Day One, Apple Notes, and Markdown files."))
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
                    .padding(.top, 12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var proImportContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            formatsCard
            pickerCard
            if !picked.isEmpty { selectionList }
            if let summary = importResult { resultCard(summary) }
        }
    }

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
            importResult = nil
            showingImporter = true
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
        .disabled(importPhase != .idle && importPhase != .done)
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
                PrimaryButton(importButtonTitle) {
                    Task { await runImport() }
                }
                .disabled(importPhase == .parsing || isWriting)

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
        if case .writing = importPhase { return true } else { return false }
    }

    private var importButtonTitle: String {
        switch importPhase {
        case .idle, .done: return String(localized: "Import")
        case .parsing:     return String(localized: "Reading…")
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

    private func runImport() async {
        importPhase = .parsing
        let urls = picked
        let parseResult: MarkdownImporter.Result
        do {
            parseResult = try MarkdownImporter().parse(fileURLs: urls)
        } catch {
            importResult = ImportSummary(imported: 0, errors: [error.localizedDescription])
            importPhase = .done
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
                // batch; users have already approved the import.
                continue
            }
            importPhase = .writing(progress: Double(index + 1) / Double(total))
        }

        analyticsService.log(
            event: "import_markdown",
            parameters: [
                "files": .int(urls.count),
                "entries_imported": .int(written),
                "entries_skipped": .int(parseResult.entries.count - written),
            ]
        )

        importResult = ImportSummary(imported: written, errors: parseResult.errors)
        picked = []
        importPhase = .done
    }
}

// MARK: - PDF template picker (shared)

/// Lets a Pro user pick which PDF template to render before the export
/// runs. Three cards stacked vertically — name, one-line description,
/// faint thumbnail cue. Tap a card → fires the export and dismisses.
private struct PDFTemplatePickerSheet: View {
    let onPick: (PDFTemplate) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PDFTemplate.allCases, id: \.self) { template in
                        TemplateCard(template: template) { onPick(template) }
                    }
                }
                .padding(20)
            }
            .navigationTitle(String(localized: "PDF template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: PDFTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                thumbnail
                    .frame(width: 56, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(MiraPalette.primaryText.opacity(0.1), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(template.descriptionText)
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
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
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            Color.white
            switch template {
            case .minimal:
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(Color.black.opacity(0.7)).frame(width: 28, height: 4)
                    ForEach(0..<6, id: \.self) { _ in
                        Capsule().fill(Color.black.opacity(0.18)).frame(height: 2)
                    }
                }
                .padding(8)
            case .editorial:
                VStack(alignment: .leading, spacing: 4) {
                    Text("J")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(.black.opacity(0.85))
                    Rectangle().fill(Color.black.opacity(0.4)).frame(height: 0.5)
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule().fill(Color.black.opacity(0.18)).frame(height: 2)
                    }
                }
                .padding(8)
            case .notebook:
                VStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle().fill(Color.blue.opacity(0.18)).frame(height: 0.5)
                    }
                }
                .padding(8)
            }
        }
    }
}

private extension PDFTemplate {
    var displayName: LocalizedStringKey {
        switch self {
        case .minimal:   return "Minimal"
        case .editorial: return "Editorial"
        case .notebook:  return "Notebook"
        }
    }

    var descriptionText: LocalizedStringKey {
        switch self {
        case .minimal:
            return "Sans-serif. Generous whitespace. The classic."
        case .editorial:
            return "Serif headings, drop caps, rule dividers between entries."
        case .notebook:
            return "Faint paper rules under serif body. Made for printing."
        }
    }
}
