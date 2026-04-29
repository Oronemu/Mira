import SwiftUI
import DesignSystem
import Utilities

struct LockScreenView: View {
    let state: LockState
    @State private var pulseInner = false
    @State private var pulseOuter = false

    var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [2, 3], intensity: 0.85)

            VStack(spacing: 0) {
                Spacer()
                medallion
                    .padding(.bottom, 36)

                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(MiraTypography.hero)
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .eyebrowStyle()
                }

                if let error = state.lastError {
                    ErrorPill(error)
                        .padding(.top, 20)
                        .padding(.horizontal, 32)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Spacer()
                unlockButton
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.lastError)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: state.isAuthenticating)
        .task { await state.attemptUnlock() }
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            PulsingRing(phase: pulseOuter, delay: 0)
            PulsingRing(phase: pulseInner, delay: 1.3)

            Circle()
                .fill(MiraPalette.moodSoft(level: 3))
                .frame(width: 126, height: 126)
                .blur(radius: 20)

            Circle()
                .frame(width: 118, height: 118)
                .glassEffect(.regular, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 12)

            Image(systemName: biometryIcon)
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                .symbolEffect(.breathe, options: .repeating)
        }
        .onAppear {
            pulseOuter = true
            pulseInner = true
        }
    }

    // MARK: - Unlock button

    private var unlockButton: some View {
        Button {
            Task { await state.attemptUnlock() }
        } label: {
            HStack(spacing: 10) {
                if state.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: biometryIcon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(buttonTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText)
            .frame(minWidth: 200)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(state.isAuthenticating)
        .sensoryFeedback(.impact(weight: .light), trigger: state.isAuthenticating)
    }

    // MARK: - Biometry adapter

    private var biometryIcon: String {
        switch state.biometryKind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcodeOnly: "lock.fill"
        case .none: "lock.slash"
        }
    }

    private var buttonTitle: LocalizedStringKey {
        if state.isAuthenticating { return "Unlocking…" }
        switch state.biometryKind {
        case .faceID: return "Use Face ID"
        case .touchID: return "Use Touch ID"
        case .opticID: return "Use Optic ID"
        case .passcodeOnly: return "Unlock with Passcode"
        case .none: return "Unavailable"
        }
    }
}

// MARK: - Pulsing ring

private struct PulsingRing: View {
    /// Bound to an `@State` bool from the parent that flips to `true` once on
    /// appear. The indefinite `repeatForever` animation carries it.
    let phase: Bool
    let delay: Double

    var body: some View {
        Circle()
            .stroke(MiraPalette.primaryText.opacity(0.18), lineWidth: 1)
            .frame(width: 130, height: 130)
            .scaleEffect(phase ? 1.55 : 1.0)
            .opacity(phase ? 0 : 0.7)
            .animation(
                .easeOut(duration: 2.6)
                .delay(delay)
                .repeatForever(autoreverses: false),
                value: phase
            )
    }
}

