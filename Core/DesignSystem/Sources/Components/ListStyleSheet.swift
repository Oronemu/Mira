import SwiftUI
import CoreKit

/// Bottom sheet for picking the list style of the current editor line plus
/// performing nesting (indent / outdent). The callbacks are deliberately
/// fine-grained — the host view owns the state, this sheet only dispatches.
public struct ListStyleSheet: View {
    /// What the cursor line currently is. Controls which radio is selected,
    /// what the indent/outdent row is enabled against.
    public let currentKind: EntryLineToken.Kind
    public let canOutdent: Bool

    public let apply: (EntryContentEditor.ListAction) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        currentKind: EntryLineToken.Kind,
        canOutdent: Bool,
        apply: @escaping (EntryContentEditor.ListAction) -> Void
    ) {
        self.currentKind = currentKind
        self.canOutdent = canOutdent
        self.apply = apply
    }

    public var body: some View {
        VStack(spacing: 0) {
            dragHandle

            HStack(alignment: .firstTextBaseline) {
                Text("List style")
                    .font(MiraTypography.displayTitle)
                    .foregroundStyle(MiraPalette.primaryText)
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
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 14) {
                    option(
                        kind: .paragraph,
                        title: "None",
                        preview: { PlainPreview() }
                    )
                    option(
                        kind: .bullet,
                        title: "Bulleted",
                        preview: { BulletPreview() }
                    )
                    option(
                        kind: .numbered,
                        title: "Numbered",
                        preview: { NumberedPreview() }
                    )

                    nestingRow
                        .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .presentationCornerRadius(36)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(MiraPalette.primaryText.opacity(0.14))
            .frame(width: 42, height: 5)
            .padding(.top, 10)
    }

    // MARK: - Option row

    private func option<Preview: View>(
        kind: EntryLineToken.Kind,
        title: LocalizedStringKey,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        let isSelected = currentKind == kind
        return Button {
            switch kind {
            case .paragraph:
                // Toggling the current kind again strips the marker —
                // achieved by calling the same toggle action.
                if currentKind == .bullet { apply(.toggleBullet) }
                else if currentKind == .numbered { apply(.toggleNumbered) }
            case .bullet:
                if currentKind != .bullet { apply(.toggleBullet) }
            case .numbered:
                if currentKind != .numbered { apply(.toggleNumbered) }
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                radio(isOn: isSelected)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MiraPalette.primaryText)
                    preview()
                        .foregroundStyle(MiraPalette.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MiraPalette.secondaryBackground)
            )
            // Without the inline opaque sheet background, the row's hit
            // area defaulted to the rendered (rounded) shape — taps in
            // the corners passed through. Force a rectangular hit area
            // so the entire card responds.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func radio(isOn: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isOn ? MiraPalette.accent : MiraPalette.secondaryText.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if isOn {
                Circle()
                    .fill(MiraPalette.accent)
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: - Nesting row

    private var nestingRow: some View {
        HStack(spacing: 12) {
            nestingButton(
                title: "Outdent",
                systemImage: "decrease.indent",
                enabled: canOutdent && currentKind != .paragraph,
                action: { apply(.outdent) }
            )
            nestingButton(
                title: "Indent",
                systemImage: "increase.indent",
                enabled: currentKind != .paragraph,
                action: { apply(.indent) }
            )
        }
    }

    private func nestingButton(
        title: LocalizedStringKey,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(enabled ? MiraPalette.primaryText : MiraPalette.secondaryText.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MiraPalette.secondaryBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Preview renderers

private struct PlainPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plain paragraph.")
            Text("No markers, wraps as prose.")
        }
        .font(.system(size: 13))
    }
}

private struct BulletPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            bulletRow("•", "First item")
            bulletRow("•", "Second item")
            bulletRow("•", "  Nested", indent: 1)
        }
        .font(.system(size: 13))
    }

    private func bulletRow(_ marker: String, _ text: LocalizedStringKey, indent: Int = 0) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(marker).frame(width: 12, alignment: .trailing)
            Text(text)
        }
        .padding(.leading, CGFloat(indent) * 14)
    }
}

private struct NumberedPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            numberedRow("1.", "First item")
            numberedRow("2.", "Second item")
            numberedRow("1.", "Nested", indent: 1)
        }
        .font(.system(size: 13))
    }

    private func numberedRow(_ marker: String, _ text: LocalizedStringKey, indent: Int = 0) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(marker).frame(width: 14, alignment: .trailing)
            Text(text)
        }
        .padding(.leading, CGFloat(indent) * 14)
    }
}
