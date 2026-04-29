import SwiftUI

/// Universal bottom dock used on both entry-creation and entry-edit screens.
///
/// In collapsed state (`isExpanded == false`) the dock shows three primary
/// tool buttons (mood / tags / photo) as a compact Liquid Glass capsule
/// aligned to the leading edge. When the canvas gains focus the host view
/// flips `isExpanded` to `true` and the capsule smoothly morphs into a
/// full-width pill that additionally reveals three extended tool buttons
/// (font style, lists, stickers) plus a glass filler that pushes the shape
/// to the screen edge. Morphing is handled natively by `GlassEffectContainer`
/// plus `glassEffectUnion` so the pill genuinely liquid-flows between states.
///
/// Extended slots are nil-able: passing `nil` renders the slot as a disabled
/// placeholder (reserves space, stays visually present, not tappable).
public struct EntryEditingDock: View {
    /// State for a dock slot.
    public struct Slot {
        public let indicator: Color?
        public let badgeCount: Int?
        public let isActive: Bool
        public let isDisabled: Bool
        public let action: () -> Void

        public init(
            indicator: Color? = nil,
            badgeCount: Int? = nil,
            isActive: Bool = false,
            isDisabled: Bool = false,
            action: @escaping () -> Void
        ) {
            self.indicator = indicator
            self.badgeCount = badgeCount
            self.isActive = isActive
            self.isDisabled = isDisabled
            self.action = action
        }
    }

    private let isExpanded: Bool
    private let mood: Slot
    private let tags: Slot
    private let photos: Slot
    private let fontStyle: Slot?
    private let list: Slot?
    private let stickers: Slot?

    @Namespace private var namespace

    public init(
        isExpanded: Bool,
        mood: Slot,
        tags: Slot,
        photos: Slot,
        fontStyle: Slot? = nil,
        list: Slot? = nil,
        stickers: Slot? = nil
    ) {
        self.isExpanded = isExpanded
        self.mood = mood
        self.tags = tags
        self.photos = photos
        self.fontStyle = fontStyle
        self.list = list
        self.stickers = stickers
    }

    public var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 4) {
                primaryButtons
                if isExpanded {
                    extendedButtons
                    glassFiller
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isExpanded)
    }

    @ViewBuilder
    private var primaryButtons: some View {
        glassButton(
            systemImage: "face.smiling",
            accessibilityLabel: "Set mood",
            slot: mood
        )
        glassButton(
            systemImage: "number",
            accessibilityLabel: "Tags",
            slot: tags
        )
        glassButton(
            systemImage: "photo.badge.plus",
            accessibilityLabel: "Add photo",
            slot: photos
        )
    }

    @ViewBuilder
    private var extendedButtons: some View {
        glassButton(
            systemImage: "textformat.size",
            accessibilityLabel: "Text style",
            slot: fontStyle ?? .placeholder
        )
        glassButton(
            systemImage: "list.bullet",
            accessibilityLabel: "Lists",
            slot: list ?? .placeholder
        )
        glassButton(
            systemImage: "face.dashed",
            accessibilityLabel: "Add sticker",
            slot: stickers ?? .placeholder
        )
    }

    @ViewBuilder
    private func glassButton(
        systemImage: String,
        accessibilityLabel: String,
        slot: Slot
    ) -> some View {
        GlassDockButton(
            systemImage: systemImage,
            badgeCount: slot.badgeCount,
            indicator: slot.indicator,
            isActive: slot.isActive,
            action: slot.action
        )
        .disabled(slot.isDisabled)
        .padding(4)
        .glassEffect(.regular.interactive())
        .glassEffectUnion(id: "dock", namespace: namespace)
        .accessibilityLabel(accessibilityLabel)
    }

    private var glassFiller: some View {
        Color.clear
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
            .glassEffectUnion(id: "dock", namespace: namespace)
            .accessibilityHidden(true)
    }
}

private extension EntryEditingDock.Slot {
    /// Disabled placeholder used when a host view doesn't wire up an extended
    /// slot yet — keeps the dock's visual shape consistent.
    static var placeholder: EntryEditingDock.Slot {
        EntryEditingDock.Slot(isDisabled: true, action: {})
    }
}
