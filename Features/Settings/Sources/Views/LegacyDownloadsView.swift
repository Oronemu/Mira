import SwiftUI
import AIKit
import CoreKit
import DesignSystem

/// Lists on-disk models whose repo is no longer in `LocalModelCatalog`
/// — typically left over from a previous release that shipped a
/// different catalog. The user can either keep using one of them or
/// reclaim the disk space without digging into iOS Files.
public struct LegacyDownloadsView: View {
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter

    @State private var state: LegacyDownloadsState?
    @State private var pendingDeletionID: String?

    private let reloadService: @Sendable () async -> Void

    public init(reloadService: @escaping @Sendable () async -> Void = {}) {
        self.reloadService = reloadService
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.45)

            Group {
                if let state {
                    if state.orphans.isEmpty && !state.isLoading {
                        emptyState
                    } else {
                        scrollContent(state: state)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(Text(String(localized: "Archived models")))
        .toolbarTitleDisplayMode(.inline)
        .task {
            if state == nil {
                state = LegacyDownloadsState(
                    analyticsService: analyticsService,
                    crashReporter: crashReporter,
                    reloadService: reloadService
                )
            }
            await state?.refresh()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text(String(localized: "No old downloads"))
            } icon: {
                Image(systemName: "tray")
                    .symbolRenderingMode(.hierarchical)
            }
        } description: {
            Text(String(localized: "Anything downloaded by a previous version of the app will appear here."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func scrollContent(state: LegacyDownloadsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "These models aren't in the current catalog. Pick one to keep using, or remove it to free up storage."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                LazyVStack(spacing: 14) {
                    ForEach(state.orphans) { orphan in
                        card(for: orphan, state: state)
                    }
                }

                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func card(for orphan: LocalModelManager.OrphanedDownload, state: LegacyDownloadsState) -> some View {
        let isCurrent = state.isCurrent(orphan)
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header(for: orphan, isCurrent: isCurrent)
                metaRow(for: orphan)
                actionRow(for: orphan, state: state, isCurrent: isCurrent)
            }
        }
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(MiraPalette.mood(level: 4).opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .confirmationDialog(
            Text(String(localized: "Remove this download?")),
            isPresented: Binding(
                get: { pendingDeletionID == orphan.id },
                set: { if !$0 { pendingDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Remove"), role: .destructive) {
                Task {
                    await state.remove(orphan)
                    pendingDeletionID = nil
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingDeletionID = nil
            }
        } message: {
            Text(String(format: String(localized: "%@ will be deleted from this device."), orphan.displayName))
        }
    }

    @ViewBuilder
    private func header(for orphan: LocalModelManager.OrphanedDownload, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(orphan.displayName)
                    .font(MiraTypography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(orphan.huggingFaceRepo)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if isCurrent {
                inUseBadge
            }
        }
    }

    private var inUseBadge: some View {
        Text(String(localized: "In use"))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(MiraPalette.mood(level: 4).opacity(0.25))
            )
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func metaRow(for orphan: LocalModelManager.OrphanedDownload) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.caption)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text(Self.formatBytes(orphan.sizeBytes))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func actionRow(for orphan: LocalModelManager.OrphanedDownload, state: LegacyDownloadsState, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            glassActionButton(
                title: isCurrent ? String(localized: "In use") : String(localized: "Use"),
                systemImage: isCurrent ? "checkmark.circle.fill" : "play.circle",
                tint: MiraPalette.mood(level: 4),
                isDisabled: isCurrent
            ) {
                Task { await state.use(orphan) }
            }

            glassActionButton(
                title: String(localized: "Remove"),
                systemImage: "trash",
                tint: .red,
                isDisabled: false
            ) {
                pendingDeletionID = orphan.id
            }
        }
    }

    @ViewBuilder
    private func glassActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isDisabled ? Color.secondary : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(isDisabled ? 0.18 : 0.4), lineWidth: 0.75)
                .allowsHitTesting(false)
        )
        .opacity(isDisabled ? 0.65 : 1)
        .disabled(isDisabled)
        .sensoryFeedback(.impact(weight: .light), trigger: isDisabled)
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
