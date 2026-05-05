import SwiftUI

/// Floating Liquid Glass dock — a single clear glass capsule that contains a
/// row of action buttons. Designed to live on `.safeAreaInset(edge: .bottom)`.
public struct GlassDock<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 4) {
            content
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

/// Round icon button sized for `GlassDock`. Shows an optional numeric badge
/// and an optional filled-color indicator (used by the mood slot to mirror
/// the currently-selected mood colour).
public struct GlassDockButton: View {
    private let systemImage: String
    private let badgeCount: Int?
    private let indicator: Color?
    private let emoji: String?
    private let isActive: Bool
    private let activeTint: Color?
    private let symbolEffectActive: Bool
    private let action: () -> Void

    public init(
        systemImage: String,
        badgeCount: Int? = nil,
        indicator: Color? = nil,
        emoji: String? = nil,
        isActive: Bool = false,
        activeTint: Color? = nil,
        symbolEffectActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.badgeCount = badgeCount
        self.indicator = indicator
        self.emoji = emoji
        self.isActive = isActive
        self.activeTint = activeTint
        self.symbolEffectActive = symbolEffectActive
        self.action = action
    }

    /// When true, the button's circle background uses `activeTint` while the
    /// icon stays in its neutral style — used for the save button where the
    /// glyph is a constant checkmark and only the surrounding ring should
    /// pick up the current mood.
    private var useTintedBackground: Bool {
        isActive && activeTint != nil
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if let emoji {
                    // Show the active emoji glyph (e.g. picked mood face)
                    // in place of the SF symbol. Sized to match the
                    // symbol's optical weight at this button size.
                    Text(emoji)
                        .font(.system(size: 22))
                        .transition(.scale.combined(with: .opacity))
                } else if let indicator {
                    Circle()
                        .fill(indicator)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(MiraPalette.primaryText.opacity(0.08), lineWidth: 0.5)
                        )
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: (isActive && !useTintedBackground) ? .semibold : .regular))
                        .symbolVariant((isActive && !useTintedBackground) ? .fill : .none)
                        .symbolEffect(
                            .variableColor,
                            options: .repeating,
                            isActive: symbolEffectActive
                        )
                        .foregroundStyle(
                            (isActive && !useTintedBackground)
                                ? MiraPalette.primaryText
                                : MiraPalette.primaryText.opacity(0.78)
                        )
                }
            }
            .frame(width: 44, height: 44)
            .background {
                if let activeTint, isActive {
                    Circle().fill(activeTint.opacity(0.42))
                        .overlay(Circle().stroke(activeTint.opacity(0.55), lineWidth: 0.6))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if isActive && indicator == nil {
                    Circle().fill(MiraPalette.primaryText.opacity(0.08))
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(
                            Capsule().fill(MiraPalette.accent)
                        )
                        .offset(x: 4, y: -2)
                        .contentTransition(.numericText(value: Double(badgeCount)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: indicator)
        .animation(.spring(duration: 0.3, bounce: 0.25), value: badgeCount)
    }
}

#Preview("GlassDock") {
    ZStack {
        MiraPalette.surface.ignoresSafeArea()
        VStack {
            Spacer()
            GlassDock {
                GlassDockButton(
                    systemImage: "face.smiling",
                    indicator: MiraPalette.mood(level: 4)
                ) {}
                GlassDockButton(systemImage: "number", badgeCount: 3) {}
                GlassDockButton(systemImage: "photo.badge.plus", badgeCount: 2) {}
                GlassDockButton(systemImage: "sparkles") {}
                Spacer(minLength: 4)
                GlassDockButton(systemImage: "checkmark", isActive: true) {}
            }
        }
    }
}
