import SwiftUI
import DesignSystem

/// Full-screen overlay rendered when the app is not active (app switcher,
/// incoming call, control center). Hides journal content behind an ambient
/// blur so nothing sensitive is visible in screenshots the system takes for
/// the switcher. Presence is gated by `ScreenShieldSettings`.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [2, 3], intensity: 0.85)

            Image(systemName: "leaf")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
    }
}
