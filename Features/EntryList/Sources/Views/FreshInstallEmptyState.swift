import SwiftUI
import CoreKit
import DesignSystem
import Utilities

/// Empty-state panel shown on the journal home when the user has no
/// entries. Subscribes to `SyncService.statusStream()` so the fresh
/// install case — sync is pulling entries down but the list isn't
/// populated yet — shows a live indicator instead of the misleading
/// "No entries yet" copy.
struct FreshInstallEmptyState: View {
    @Environment(\.syncService) private var syncService
    @State private var status: SyncStatus = .idle

    var body: some View {
        VStack(spacing: 12) {
            switch status {
            case .syncing:
                syncingCopy
            case .failed(let message):
                failureCopy(message)
            case .idle, .succeeded:
                defaultCopy
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .animation(.easeInOut(duration: 0.25), value: statusToken)
        .task(id: ObjectIdentifier(syncService)) {
            for await newValue in syncService.statusStream() {
                status = newValue
            }
        }
    }

    private var defaultCopy: some View {
        VStack(spacing: 12) {
            Text("No entries yet")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Start by writing your first entry.")
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var syncingCopy: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your journal")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Pulling entries from iCloud — this can take a minute on a fresh install.")
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }

    private func failureCopy(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Sync hit a snag")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text(message)
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }

    /// A value that changes whenever the visual branch changes, so the
    /// enclosing `.animation(...)` re-runs its transition. `SyncStatus`
    /// itself has associated values we don't want to trigger on.
    private var statusToken: Int {
        switch status {
        case .idle: 0
        case .syncing: 1
        case .succeeded: 2
        case .failed: 3
        }
    }
}
