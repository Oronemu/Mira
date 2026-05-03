import SwiftUI

/// Wraps premium content shown to free users behind a heavy blur and a
/// centred "Unlock Pro" CTA. When `isLocked` is false the overlay
/// becomes a no-op pass-through, so feature code can wrap the section
/// once and let the Pro flag drive presentation.
///
/// Used by Stats premium panels (tag correlations, predictions,
/// year-in-review). Consumers pass the action that raises the paywall;
/// the component knows nothing about subscription internals.
public struct PremiumOverlay<Content: View>: View {
    private let isLocked: Bool
    private let title: LocalizedStringKey
    private let onUnlock: () -> Void
    private let content: Content

    public init(
        isLocked: Bool,
        title: LocalizedStringKey = "Unlock Pro",
        onUnlock: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isLocked = isLocked
        self.title = title
        self.onUnlock = onUnlock
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .blur(radius: isLocked ? 14 : 0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(title)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .foregroundStyle(MiraPalette.primaryText)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(MiraPalette.primaryText.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the paywall")
            }
        }
    }
}
