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

    @State private var state: SettingsState?
    @State private var exportURL: IdentifiableURL?
    @State private var isExporting: Bool = false
    @State private var activeKind: ExportKind?

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
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(items: [wrapped.url])
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
                        kind: .pdf
                    ) {
                        runExport(kind: .pdf, state: state)
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
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
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

    private func runExport(kind: ExportKind, state: SettingsState) {
        guard !isExporting else { return }
        isExporting = true
        activeKind = kind
        Task {
            let url: URL?
            switch kind {
            case .markdown: url = await state.exportMarkdown()
            case .pdf: url = await state.exportPDF()
            }
            if let url { exportURL = IdentifiableURL(url: url) }
            isExporting = false
            activeKind = nil
        }
    }
}
