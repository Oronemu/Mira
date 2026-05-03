import SwiftUI
import CoreKit
import DesignSystem
import Utilities

/// Pro-only horizontal carousel of saved smart filters above the
/// entries scroll. Shown when the user has at least one saved filter
/// AND the active subscription is Pro — free users never see the
/// strip so the EntryList header stays uncluttered.
///
/// Each chip applies its filter on tap; long-press opens a context
/// menu with delete. The leading "All" chip resets the query.
struct SavedFiltersStripView: View {
    let filters: [SavedFilter]
    let activeFilterID: UUID?
    let isUnfiltered: Bool
    let onApply: (SavedFilter) -> Void
    let onClear: () -> Void
    let onDelete: (SavedFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                allChip
                ForEach(filters) { filter in
                    chip(for: filter)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }

    private var allChip: some View {
        Button(action: onClear) {
            chipLabel(text: "All", isActive: isUnfiltered)
        }
        .buttonStyle(.plain)
    }

    private func chip(for filter: SavedFilter) -> some View {
        let isActive = filter.id == activeFilterID && !isUnfiltered
        return Button { onApply(filter) } label: {
            chipLabel(text: LocalizedStringKey(filter.name), isActive: isActive)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onDelete(filter) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func chipLabel(text: LocalizedStringKey, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .serif))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive
                               ? MiraPalette.mood(level: 4).opacity(0.4)
                               : MiraPalette.secondaryBackground.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive
                        ? MiraPalette.primaryText.opacity(0.5)
                        : MiraPalette.primaryText.opacity(0.08),
                    lineWidth: 1
                )
            )
            .foregroundStyle(MiraPalette.primaryText)
    }
}
