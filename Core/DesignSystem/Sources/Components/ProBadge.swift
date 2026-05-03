import SwiftUI

/// Compact "PRO" pill placed on Settings rows whose tap leads to the
/// paywall for free users. Kept intentionally small (caption-sized) so
/// it labels the row rather than competing with its title — the row's
/// own copy still describes the feature.
///
/// Reused across Phase 5–7 paywall surfaces (PDF templates, themes /
/// icons, advanced stats); centralising the visual here keeps badges
/// uniform when more land.
public struct ProBadge: View {
    public init() {}

    public var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(MiraPalette.primaryText)
            .background(
                Capsule().fill(MiraPalette.mood(level: 5).opacity(0.28))
            )
            .overlay(
                Capsule().strokeBorder(MiraPalette.mood(level: 5).opacity(0.5), lineWidth: 0.5)
            )
            .accessibilityLabel(Text("Pro feature"))
    }
}

#Preview {
    HStack(spacing: 12) {
        Text("PDF").font(MiraTypography.body)
        ProBadge()
    }
    .padding()
}
