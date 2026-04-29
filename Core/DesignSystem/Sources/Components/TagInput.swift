import SwiftUI

public struct TagInput: View {
    private let tags: [String]
    private let onAdd: (String) -> Void
    private let onRemove: (String) -> Void

    public init(
        tags: [String],
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void
    ) {
        self.tags = tags
        self.onAdd = onAdd
        self.onRemove = onRemove
    }

    public var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChip(tag) { onRemove(tag) }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
            AddTagPill(onSubmit: onAdd)
        }
        .animation(.spring(duration: 0.3, bounce: 0.25), value: tags)
    }
}

// MARK: - Chip

private struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    init(_ text: String, onRemove: @escaping () -> Void) {
        self.text = text
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Remove tag \(text)"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(MiraPalette.secondaryBackground))
    }
}

// MARK: - Add pill

private struct AddTagPill: View {
    let onSubmit: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("tag", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focused)
                    .frame(minWidth: 56)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .font(.system(size: 13, weight: .medium))
                    .background(Capsule().fill(MiraPalette.secondaryBackground))
                    .overlay(
                        Capsule().strokeBorder(MiraPalette.accent.opacity(0.45), lineWidth: 1)
                    )
                    .onSubmit(commit)
                    .onAppear { focused = true }
                    .onChange(of: focused) { _, newValue in
                        if !newValue { commit() }
                    }
            } else {
                Button {
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Tag")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().strokeBorder(MiraPalette.secondaryText.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add tag")
            }
        }
    }

    private func commit() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { onSubmit(value) }
        draft = ""
        isEditing = false
    }
}

// MARK: - FlowLayout

/// Minimal wrapping layout. Children are laid out left-to-right; when the
/// current row overflows the proposed width, the next child wraps onto a new
/// line. Spacing is uniform both horizontally and vertically.
///
/// Internal (not `private`) so other DesignSystem components — e.g.
/// `TagsSheet`'s recent-tag cloud — can reuse it without re-implementing.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // SwiftUI sometimes calls sizeThatFits with an unspecified width
        // (e.g. when measuring inside certain ScrollView / Layout nestings).
        // If we treat that as `.infinity` we'd report a single-row sum and
        // the parent would grant the layout that wide frame — wrap never
        // happens. Substitute the screen width as a reasonable fallback so
        // the *preferred* size we return is already wrapped.
        let maxWidth = effectiveMaxWidth(proposal)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: min(totalWidth, maxWidth), height: y + rowHeight)
    }

    private func effectiveMaxWidth(_ proposal: ProposedViewSize) -> CGFloat {
        if let width = proposal.width, width > 0, width < .infinity {
            return width
        }
        return UIScreen.main.bounds.width
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
