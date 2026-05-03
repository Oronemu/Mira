import SwiftUI
import CoreKit
import DesignSystem
import Utilities

public struct AppearanceSettingsView: View {
    @Environment(\.appearanceState) private var state
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    @State private var status: SubscriptionStatus = .unknown
    @State private var showingCustomPicker = false
    @State private var pendingCustomColor: Color = .accentColor

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

                    iconRow

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
        .task {
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
        .sheet(isPresented: $showingCustomPicker) {
            customColorSheet
                .presentationDetents([.medium])
        }
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
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Accent")

            // Free row — five mood-aliased presets, always tappable.
            HStack(spacing: 14) {
                ForEach(AccentTint.allCases, id: \.self) { tint in
                    AccentSwatch(
                        color: MiraPalette.mood(level: tint.rawValue),
                        isSelected: isFreeAccentSelected(tint),
                        showsProBadge: false
                    ) { state.setAccent(tint) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Pro row — gated. Tap without entitlement raises the
            // paywall instead of applying.
            HStack(spacing: 14) {
                ForEach(ProAccent.allCases, id: \.self) { pro in
                    AccentSwatch(
                        color: MiraPalette.proAccent(pro),
                        isSelected: state.settings.proAccent == pro,
                        showsProBadge: !status.isPro
                    ) {
                        if status.isPro {
                            state.setProAccent(pro)
                        } else {
                            paywallPresenter.present(.feature(.themesAndIcons))
                        }
                    }
                }

                customSwatch
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(activeAccentName)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(MiraPalette.secondaryText)
                .animation(.easeInOut(duration: 0.2), value: state.settings)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.settings)
    }

    /// "Custom" picker sits in the same row as Pro presets. Renders
    /// either the user's chosen hex or a neutral placeholder when
    /// unset, with a small "+"/dot to disambiguate from a regular
    /// swatch.
    private var customSwatch: some View {
        let isCustomActive = state.settings.customAccentHex != nil
        let displayColor: Color = isCustomActive
            ? MiraPalette.tintColor(for: state.settings)
            : MiraPalette.secondaryBackground
        return Button {
            if status.isPro {
                pendingCustomColor = displayColor
                showingCustomPicker = true
            } else {
                paywallPresenter.present(.feature(.themesAndIcons))
            }
        } label: {
            ZStack {
                Circle()
                    .fill(displayColor)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().strokeBorder(MiraPalette.primaryText.opacity(0.15), lineWidth: 1)
                    )
                Image(systemName: isCustomActive ? "drop.fill" : "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))

                if isCustomActive {
                    Circle()
                        .strokeBorder(MiraPalette.primaryText.opacity(0.85), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                if !status.isPro {
                    ProBadge()
                        .scaleEffect(0.75)
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var customColorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                ColorPicker(
                    String(localized: "Custom accent"),
                    selection: $pendingCustomColor,
                    supportsOpacity: false
                )
                .font(MiraTypography.body)

                Text(String(localized: "Pick any colour. Mira will use it across tabs, chips, and progress bars."))
                    .font(MiraTypography.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(20)
            .navigationTitle(String(localized: "Custom accent"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { showingCustomPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Apply")) {
                        if let hex = pendingCustomColor.hexString {
                            state.setCustomAccent(hex: hex)
                        }
                        showingCustomPicker = false
                    }
                }
            }
        }
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .eyebrowStyle()
            .padding(.leading, 4)
    }

    // MARK: - Icon row

    private var iconRow: some View {
        NavigationLink {
            IconPickerView()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "app.badge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: 4).opacity(0.18)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(String(localized: "App icon"))
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText)
                        if !status.isPro {
                            ProBadge()
                        }
                    }
                    Text(String(localized: "Pick the look that fits your home screen"))
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection helpers

    private func isFreeAccentSelected(_ tint: AccentTint) -> Bool {
        // The free row only highlights when no Pro override is active —
        // otherwise the user might think two accents are simultaneously
        // applied.
        guard state.settings.proAccent == nil,
              state.settings.customAccentHex == nil else { return false }
        return state.accent == tint
    }

    private var activeAccentName: LocalizedStringKey {
        if state.settings.customAccentHex != nil {
            return "Custom"
        }
        if let pro = state.settings.proAccent {
            return pro.displayName
        }
        return state.accent.displayName
    }
}

// MARK: - Swatch

private struct AccentSwatch: View {
    let color: Color
    let isSelected: Bool
    let showsProBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)

                if isSelected {
                    Circle()
                        .strokeBorder(MiraPalette.primaryText.opacity(0.85), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                if showsProBadge {
                    ProBadge()
                        .scaleEffect(0.75)
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Color → hex

private extension Color {
    /// Resolves the Color to a `#RRGGBB` string by sampling the
    /// underlying UIColor in the sRGB color space. Returns nil if the
    /// underlying color can't be expressed in RGBA (e.g. some dynamic
    /// system colours).
    var hexString: String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
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

private extension ProAccent {
    var displayName: LocalizedStringKey {
        switch self {
        case .rose:   return "Rose"
        case .ocean:  return "Ocean"
        case .forest: return "Forest"
        case .gold:   return "Gold"
        case .plum:   return "Plum"
        }
    }
}
