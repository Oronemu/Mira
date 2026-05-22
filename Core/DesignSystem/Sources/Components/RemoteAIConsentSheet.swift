import SwiftUI
import Utilities

/// Modal sheet asking for explicit consent to send journal context to a
/// third-party AI service. Required by Apple App Store Review guideline
/// 5.1.1(i) / 5.1.2(i) — privacy-policy text alone is not enough, the
/// user has to see an in-app disclosure that names the data, names the
/// recipient, and asks for permission *before* anything is sent.
///
/// Presented from three places:
/// 1. Settings → Intelligence → Cloud (when flipping the provider on).
/// 2. Ask Mira composer (first send with Cloud selected).
/// 3. Reflections → Generate now (first manual reflection with Cloud).
///
/// The auto-reflection BGTask path doesn't surface UI; `AIProviderFactory`
/// also checks the same consent flag and silently falls back to the
/// on-device model when consent is missing.
public struct RemoteAIConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.legalLinks) private var legalLinks
    @Environment(\.openURL) private var openURL

    private let onAllow: () -> Void
    private let onDeny: () -> Void

    public init(
        onAllow: @escaping () -> Void,
        onDeny: @escaping () -> Void = {}
    ) {
        self.onAllow = onAllow
        self.onDeny = onDeny
    }

    public var body: some View {
        MiraSheetChrome(moodLevels: [3, 4], intensity: 0.4) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        hero
                        intro
                        bulletsCard
                        recipientCard
                        privacyLink
                        settingsHint
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                buttons
            }
        }
        .miraSheet([.large])
        .interactiveDismissDisabled()
    }

    // MARK: - Subviews

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            MiraDragHandle()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            HStack(spacing: 14) {
                Image(systemName: "cloud")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(MiraPalette.mood(level: 4).opacity(0.20)))

                Text(String(localized: "Use Mira's cloud AI?", comment: "Remote AI consent — sheet title (short, non-technical)"))
                    .font(MiraTypography.displayTitle)
                    .foregroundStyle(MiraPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var intro: some View {
        Text(String(localized: "Cloud AI gives you deeper answers and richer reflections. To do that, Mira needs to send a small amount of your writing to an outside AI service.", comment: "Remote AI consent — warm intro paragraph"))
            .font(.system(.body, design: .serif))
            .foregroundStyle(MiraPalette.primaryText.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bulletsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "What Mira sends", comment: "Remote AI consent — bullet section heading"))
                .eyebrowStyle()

            VStack(alignment: .leading, spacing: 10) {
                bullet(String(localized: "Your question or prompt", comment: "Remote AI consent — bullet 1"))
                bullet(String(localized: "A few of your most relevant journal entries - text, mood, tags", comment: "Remote AI consent — bullet 2"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.mood(level: 4).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MiraPalette.mood(level: 4).opacity(0.30), lineWidth: 1)
        )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("•")
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.mood(level: 4))
            Text(text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recipientCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: 5))
                Text(String(localized: "Who receives it", comment: "Remote AI consent — recipient card heading"))
                    .font(MiraTypography.headline)
                    .foregroundStyle(MiraPalette.primaryText)
            }

            Text(String(localized: "The AI service is Anthropic. They use your request only to generate the reply and don't train their models on it. Mira doesn't keep the content of your messages or entries on its servers.", comment: "Remote AI consent — recipient/handling explanation"))
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.mood(level: 5).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MiraPalette.mood(level: 5).opacity(0.30), lineWidth: 1)
        )
    }

    private var privacyLink: some View {
        Button {
            openURL(legalLinks.privacyURL)
        } label: {
            HStack(spacing: 4) {
                Text(String(localized: "Privacy Policy", comment: "Link to the in-app privacy policy"))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.75)
            }
            .font(MiraTypography.caption)
            .foregroundStyle(MiraPalette.secondaryText)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsHint: some View {
        Text(String(localized: "You can change this anytime in Settings.", comment: "Remote AI consent — settings hint"))
            .font(.system(size: 13))
            .foregroundStyle(MiraPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                RemoteAIConsentStore().grant()
                onAllow()
                dismiss()
            } label: {
                Text(String(localized: "Allow", comment: "Remote AI consent — primary action, grants permission"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(
                Capsule().fill(MiraPalette.mood(level: 4).opacity(0.28))
            )
            .glassEffect(.regular.interactive(), in: Capsule())

            Button {
                onDeny()
                dismiss()
            } label: {
                Text(String(localized: "Don't Allow", comment: "Remote AI consent — secondary action, declines permission"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}
