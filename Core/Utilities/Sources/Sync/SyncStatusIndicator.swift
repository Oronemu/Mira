import SwiftUI

/// Small inline indicator that fades in a spinner + "Syncing…" while
/// the `SyncService` is busy, then briefly shows "Synced" when a cycle
/// finishes, then disappears. Silent in the `idle` state so it doesn't
/// clutter the header when the user hasn't turned sync on.
public struct SyncStatusIndicator: View {
    @Environment(\.syncService) private var syncService
    @State private var status: SyncStatus = .idle
    @State private var showJustSynced: Bool = false

    public init() {}

    public var body: some View {
        content
            .animation(.easeInOut(duration: 0.25), value: presentation)
            .task(id: ObjectIdentifier(syncService)) {
                for await newValue in syncService.statusStream() {
                    if case .syncing = status, case .succeeded = newValue {
                        // Flash "Synced" briefly so the user sees the
                        // cycle completed even if nothing changed.
                        showJustSynced = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            await MainActor.run { showJustSynced = false }
                        }
                    }
                    status = newValue
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .hidden:
            EmptyView()
        case .syncing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Syncing…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        case .justSynced:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 10, weight: .medium))
                Text("Synced")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .transition(.opacity)
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 10, weight: .medium))
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.red.opacity(0.8))
            .transition(.opacity)
        }
    }

    private enum Presentation: Equatable {
        case hidden
        case syncing
        case justSynced
        case failed(String)
    }

    private var presentation: Presentation {
        switch status {
        case .syncing: .syncing
        case .failed(let message): .failed(message)
        case .succeeded where showJustSynced: .justSynced
        default: .hidden
        }
    }
}
