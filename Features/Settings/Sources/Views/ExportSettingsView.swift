import SwiftUI
import CoreKit
import Utilities
import AIKit
import DesignSystem

public struct ExportSettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    @State private var state: SettingsState?
    @State private var exportURL: IdentifiableURL?
    @State private var isExporting: Bool = false
    @State private var activeKind: ExportKind?
    @State private var status: SubscriptionStatus = .unknown
    @State private var showingTemplatePicker: Bool = false

    private enum ExportKind: Hashable {
        case markdown, pdf
    }

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            Group {
                if let state {
                    content(state: state)
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
        .collapsibleHeroTitle("Export")
        .task {
            if state == nil {
                state = SettingsState(
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
            // Track Pro status so the PDF card can render the badge and
            // the tap handler can gate without an extra service call.
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
        .sheet(isPresented: $showingTemplatePicker) {
            if let state {
                PDFTemplatePickerSheet { template in
                    showingTemplatePicker = false
                    runExport(kind: .pdf, template: template, state: state)
                } onCancel: {
                    showingTemplatePicker = false
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func content(state: SettingsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHero(
                    title: "Export",
                    subtitle: "Take every entry with you"
                )

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

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
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
                        if showsProBadge {
                            ProBadge()
                        }
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
            case .pdf: url = await state.exportPDF(template: template)
            }
            if let url { exportURL = IdentifiableURL(url: url) }
            isExporting = false
            activeKind = nil
        }
    }
}

// MARK: - Template picker sheet

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

    /// Tiny visual cue per template — not a real PDF preview, just a
    /// stylised page that hints at the typography choice. Real previews
    /// would require pre-baking PNGs from sample data; out of scope for
    /// the first cut.
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
