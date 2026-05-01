import SwiftUI
import DesignSystem

public struct SettingsView: View {
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

                    VStack(spacing: 10) {
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

                        SettingsCategoryLink(
                            icon: "bell",
                            title: "Reminders",
                            subtitle: "Local pushes — daily check-in and a nudge if you've been quiet",
                            moodLevel: 5
                        ) { NotificationSettingsView() }

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
                            icon: "paintpalette",
                            title: "Appearance",
                            subtitle: "Theme and accent color",
                            moodLevel: 3
                        ) { AppearanceSettingsView() }

                        SettingsCategoryLink(
                            icon: "square.and.arrow.up",
                            title: "Export",
                            subtitle: "Markdown or PDF of every entry",
                            moodLevel: 2
                        ) { ExportSettingsView() }

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
