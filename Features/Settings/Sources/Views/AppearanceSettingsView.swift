import SwiftUI
import DesignSystem
import Utilities

public struct AppearanceSettingsView: View {
    @Environment(\.appearanceState) private var state

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(
                moodLevels: [state.accent.rawValue],
                intensity: 0.55
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsHero(
                        title: "Appearance",
                        subtitle: "How Mira looks"
                    )

                    themeSection

                    accentSection

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
        .collapsibleHeroTitle("Appearance")
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Theme")

            SettingsOptionCard(
                icon: "circle.lefthalf.filled",
                title: "System",
                subtitle: "Follow device setting.",
                moodLevel: 3,
                isSelected: state.theme == .system
            ) { state.setTheme(.system) }

            SettingsOptionCard(
                icon: "sun.max",
                title: "Light",
                subtitle: "Warm paper even in the dark.",
                moodLevel: 4,
                isSelected: state.theme == .light
            ) { state.setTheme(.light) }

            SettingsOptionCard(
                icon: "moon",
                title: "Dark",
                subtitle: "Deep ink, for late writing.",
                moodLevel: 2,
                isSelected: state.theme == .dark
            ) { state.setTheme(.dark) }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.theme)
    }

    // MARK: - Accent

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Accent")

            HStack(spacing: 14) {
                ForEach(AccentTint.allCases, id: \.self) { tint in
                    AccentSwatch(
                        tint: tint,
                        isSelected: state.accent == tint
                    ) { state.setAccent(tint) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)

            Text(state.accent.displayName)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(MiraPalette.secondaryText)
                .animation(.easeInOut(duration: 0.2), value: state.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.accent)
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .eyebrowStyle()
            .padding(.leading, 4)
    }
}

// MARK: - Swatch

private struct AccentSwatch: View {
    let tint: AccentTint
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(MiraPalette.mood(level: tint.rawValue))
                    .frame(width: 34, height: 34)

                if isSelected {
                    Circle()
                        .strokeBorder(MiraPalette.primaryText.opacity(0.85), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Localized names

private extension AccentTint {
    var displayName: LocalizedStringKey {
        switch self {
        case .cool:     return "Cool"
        case .lavender: return "Lavender"
        case .sand:     return "Sand"
        case .clay:     return "Clay"
        case .sage:     return "Sage"
        }
    }
}
