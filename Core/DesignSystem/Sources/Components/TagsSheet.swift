import SwiftUI
import CoreKit

/// Modal tag editor — sectioned so the sheet feels filled rather than a
/// pill afloat in empty space. The user's active tags sit in their own
/// "On this entry" block (FlowLayout via TagInput) with a count badge in
/// the header; recent tags from earlier entries appear below as a
/// wrapping chip cloud one tap away. When the user has no tags yet and
/// no recent vocabulary on file, a quiet empty-state hint takes the
/// place of the recent block.
public struct TagsSheet: View {
    private let tags: [String]
    private let onAdd: (String) -> Void
    private let onRemove: (String) -> Void
    private let repository: any EntryRepository

    @Environment(\.dismiss) private var dismiss
    @State private var recent: [String] = []

    public init(
        tags: [String],
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void,
        repository: any EntryRepository
    ) {
        self.tags = tags
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.repository = repository
    }

    public var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    activeSection

                    if !unusedRecent.isEmpty {
                        recentSection
                    } else if tags.isEmpty {
                        emptyHint
                    }
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .presentationCornerRadius(36)
        .task { await loadRecent() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tags")
                    .font(MiraTypography.displayTitle)
                    .foregroundStyle(MiraPalette.primaryText)
                if !tags.isEmpty {
                    Text("\(tags.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.smooth(duration: 0.2), value: tags.count)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: - Active section

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On this entry")
                .eyebrowStyle()
                .padding(.horizontal, 24)
            TagInput(tags: tags, onAdd: onAdd, onRemove: onRemove)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Recent section — chip cloud

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .eyebrowStyle()
                .padding(.horizontal, 24)
            FlowLayout(spacing: 8) {
                ForEach(unusedRecent, id: \.self) { tag in
                    recentChip(tag)
                }
            }
            // Explicit max-width frame so SwiftUI feeds FlowLayout a
            // finite proposal even when the surrounding ScrollView /
            // VStack chain wouldn't on its own — that's the difference
            // between "single row that overflows" and "wraps to next
            // line" when there are many recent tags.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Empty state

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag freely")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText)
            Text("Mira remembers your vocabulary and brings it back when you write.")
                .font(.system(size: 13))
                .foregroundStyle(MiraPalette.secondaryText)
                .lineLimit(3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private var unusedRecent: [String] {
        let active = Set(tags)
        return recent.filter { !active.contains($0) }
    }

    private func recentChip(_ tag: String) -> some View {
        Button {
            onAdd(tag)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text(tag)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var dragHandle: some View {
        Capsule()
            .fill(MiraPalette.primaryText.opacity(0.14))
            .frame(width: 42, height: 5)
            .padding(.top, 10)
    }

    private func loadRecent() async {
        let fetched = (try? await repository.recentTags(limit: 24)) ?? []
        withAnimation(.smooth(duration: 0.3)) {
            recent = fetched
        }
    }
}
