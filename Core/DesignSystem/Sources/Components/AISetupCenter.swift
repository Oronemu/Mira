import SwiftUI
import Utilities

/// Full-screen empty state shown when no AI provider is configured.
/// Replaces the old technical "AI provider is not available" error with
/// a quiet, centered invitation. The hero icon sits inside a soft mood
/// halo, the copy adapts to which provider the user picked, and a single
/// glass capsule deep-links into Intelligence settings.
public struct AISetupCenter: View {
    private let providerKind: AISettings.ProviderKind
    private let onOpenSettings: () -> Void

    public init(
        providerKind: AISettings.ProviderKind,
        onOpenSettings: @escaping () -> Void
    ) {
        self.providerKind = providerKind
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(MiraPalette.mood(level: 4).opacity(0.16))
                    .frame(width: 132, height: 132)
                    .blur(radius: 18)
                Circle()
                    .fill(MiraPalette.mood(level: 4).opacity(0.22))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.88))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(subtitle)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 12)

            Button(action: onOpenSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text(buttonLabel)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(MiraPalette.primaryText)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(
                Capsule().fill(MiraPalette.mood(level: 3).opacity(0.25))
            )
            .glassEffect(.regular.interactive(), in: Capsule())
            .padding(.top, 4)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: String {
        switch providerKind {
        case .off:    "sparkles"
        case .local:  "iphone"
        case .remote: "cloud"
        }
    }

    private var title: String {
        switch providerKind {
        case .off:
            String(localized: "Turn on Mira's AI")
        case .local:
            String(localized: "Download an on-device model")
        case .remote:
            String(localized: "Finish setting up cloud AI")
        }
    }

    private var subtitle: String {
        switch providerKind {
        case .off:
            String(localized: "Choose on-device for full privacy or cloud for richer answers. Either way, Mira needs a brain to talk to your journal.")
        case .local:
            String(localized: "Pick a model in Intelligence settings — once it's downloaded, you can ask anything fully offline.")
        case .remote:
            String(localized: "Add an API key in Intelligence settings, or unlock Mira Pro to use the hosted backend.")
        }
    }

    private var buttonLabel: String {
        String(localized: "Open Intelligence settings")
    }
}
