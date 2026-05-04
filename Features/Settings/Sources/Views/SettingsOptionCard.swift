import SwiftUI
import DesignSystem

/// Reusable pick-one-of-N tile used across the Settings detail screens
/// (Intelligence provider, Privacy biometric mode, Reflection frequency).
/// Full-width glass card with an icon bubble, serif title, short subtitle,
/// and a mood-tinted radio dot on the trailing edge.
struct SettingsOptionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let moodLevel: Int
    let isSelected: Bool
    var isEnabled: Bool = true
    var showsProBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(isSelected ? 0.3 : 0.15)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText)
                        if showsProBadge { ProBadge() }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? MiraPalette.mood(level: moodLevel)
                                : MiraPalette.primaryText.opacity(0.2),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(MiraPalette.mood(level: moodLevel))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 10)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MiraPalette.mood(level: moodLevel).opacity(0.08))
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(MiraPalette.mood(level: moodLevel).opacity(0.4), lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Section hero

struct SettingsHero: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
            Text(subtitle).eyebrowStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

// MARK: - Primary glass action

struct SettingsGlassAction: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var tintLevel: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if let tintLevel {
                Capsule().fill(MiraPalette.mood(level: tintLevel).opacity(0.25))
            }
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
