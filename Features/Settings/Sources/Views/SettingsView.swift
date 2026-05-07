import SwiftUI
import CoreKit
import DesignSystem

public struct SettingsView: View {
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @State private var status: SubscriptionStatus = .unknown

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsHero(
                        title: "Settings",
                        subtitle: "Tune how Mira looks, thinks, and protects your journal"
                    )

                    proBanner

                    settingsSection("Artificial intelligence") {
                        SettingsCategoryLink(
                            icon: "sparkles",
                            title: "Intelligence",
                            subtitle: "AI provider, on-device model, remote API",
                            moodLevel: 5
                        ) { IntelligenceSettingsView() }

                        SettingsCategoryLink(
                            icon: "text.bubble",
                            title: "Reflections",
                            subtitle: "How often Mira drafts a reflection for you",
                            moodLevel: 4
                        ) { ReflectionSettingsView() }
                    }

                    settingsSection("Personalization") {
                        habitsAndGoalsRow

                        SettingsCategoryLink(
                            icon: "paintpalette",
                            title: "Appearance",
                            subtitle: "Theme and accent color",
                            moodLevel: 3
                        ) { AppearanceSettingsView() }

                        SettingsCategoryLink(
                            icon: "bell",
                            title: "Reminders",
                            subtitle: "Local pushes — daily check-in and a nudge if you've been quiet",
                            moodLevel: 5
                        ) { NotificationSettingsView() }
                    }

                    settingsSection("Privacy & data") {
                        SettingsCategoryLink(
                            icon: "lock",
                            title: "Privacy",
                            subtitle: "Biometric lock on this device",
                            moodLevel: 1
                        ) { PrivacySettingsView() }

                        SettingsCategoryLink(
                            icon: "icloud",
                            title: "iCloud sync",
                            subtitle: "End-to-end encrypted backup across your devices",
                            moodLevel: 2
                        ) { SyncSettingsView() }

                        SettingsCategoryLink(
                            icon: "arrow.up.arrow.down",
                            title: "Import & export",
                            subtitle: "Take entries in or out — Markdown, PDF, Day One",
                            moodLevel: 2
                        ) { ImportExportSettingsView() }
                    }

                    settingsSection("Support") {
                        SettingsCategoryLink(
                            icon: "questionmark.circle",
                            title: "Help & support",
                            subtitle: "Common questions and how to reach us",
                            moodLevel: 4
                        ) { HelpSupportView() }

                        SettingsCategoryLink(
                            icon: "info.circle",
                            title: "About",
                            subtitle: "Version and privacy policy",
                            moodLevel: 3
                        ) { AboutSettingsView() }
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .collapsibleHeroTitle("Settings")
        .task {
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
    }

    // MARK: - Section helper

    /// Group of settings cards under an eyebrow header. Mirrors the
    /// "Section" pattern of native iOS Settings but keeps our card-style
    /// rows so the screen still reads as Mira's own surface.
    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .eyebrowStyle()
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                content()
            }
        }
    }

    // MARK: - Habits & Goals row

    @ViewBuilder
    private var habitsAndGoalsRow: some View {
        if status.isPro {
            NavigationLink {
                HabitsAndGoalsView()
            } label: {
                habitsAndGoalsRowLabel(showsBadge: false, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                paywallPresenter.present(.feature(.goalsAndHabits))
            } label: {
                habitsAndGoalsRowLabel(showsBadge: true, showsChevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func habitsAndGoalsRowLabel(showsBadge: Bool, showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: 5).opacity(0.18)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(String(localized: "Habits & goals"))
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    if showsBadge { ProBadge() }
                }
                Text(String(localized: "Tag-driven targets, derived from your journal"))
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Pro banner

    @ViewBuilder
    private var proBanner: some View {
        if status.isPro {
            NavigationLink {
                ProSettingsView()
            } label: {
                proRow(
                    icon: "checkmark.seal.fill",
                    title: String(localized: "Mira Pro"),
                    subtitle: String(localized: "Active — manage your subscription")
                )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                paywallPresenter.present(.general)
            } label: {
                proRow(
                    icon: "sparkles",
                    title: String(localized: "Unlock Mira Pro"),
                    subtitle: String(localized: "Hosted AI, advanced stats, themes, and more")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func proRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(MiraTypography.headline)
                Text(subtitle).font(MiraTypography.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.tint.opacity(0.08))
        )
    }
}

// MARK: - Category link

private struct SettingsCategoryLink<Destination: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let moodLevel: Int
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(0.18)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
                    .padding(.top, 14)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
