import SwiftUI
import DesignSystem

public struct AboutSettingsView: View {
    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3, 4], intensity: 0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero

                    descriptionCard

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Resources").eyebrowStyle()
                        linkCard(
                            icon: "hand.raised",
                            title: "Privacy policy",
                            destination: privacyPolicyURL,
                            moodLevel: 4
                        )
                    }

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .staticHeroTitle("About")
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Image("MiraLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(MiraPalette.primaryText.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)

            VStack(spacing: 4) {
                Text("Mira")
                    .font(MiraTypography.hero)
                    .foregroundStyle(MiraPalette.primaryText)
                Text("Offline journal with on-device reflection")
                    .eyebrowStyle()
            }

            Text(versionLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(MiraPalette.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(MiraPalette.mood(level: 3).opacity(0.18))
                )
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 4)
    }

    // MARK: - Description

    private var descriptionCard: some View {
        Text("Mira is a private iOS journal. Your entries stay on your device — an on-device language model helps you reflect without sending your writing anywhere. Optional iCloud sync is end-to-end encrypted.")
            .font(.system(size: 15, weight: .regular, design: .serif))
            .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Links

    private func linkCard(icon: String, title: LocalizedStringKey, destination: String, moodLevel: Int) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(0.15)))

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MiraPalette.primaryText)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .buttonStyle(.plain)
    }

    // MARK: - Version

    private var versionLabel: String {
        "v\(appVersion) · Build \(appBuild)"
    }

    /// Picks the privacy policy gist matching the user's current
    /// language preference. Falls back to English for any locale other
    /// than Russian.
    private var privacyPolicyURL: String {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru"
        return isRussian
            ? "https://gist.github.com/Oronemu/9f9e89620e45f128bf9abb14f4083a45"
            : "https://gist.github.com/Oronemu/ab9bcf463cc61ac8efaacf183b58023c"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
