import SwiftUI
import UIKit
import UserNotifications
import CoreKit
import Utilities
import DesignSystem

public struct OnboardingView: View {
    @State private var state = OnboardingState()
    @State private var isRequestingPermission: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter

    private let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: backgroundMoods, intensity: 0.8)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                currentPage
                    .id(state.current)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 28, y: 0)),
                        removal: .opacity.combined(with: .offset(x: -28, y: 0))
                    ))

                Spacer(minLength: 24)

                dotIndicator
                    .padding(.bottom, 22)

                VStack(spacing: 8) {
                    primaryCTA
                    if state.current.isLast && !state.allPermissionsAnswered {
                        Text("Respond to both permissions above to continue.")
                            .font(.system(size: 12))
                            .foregroundStyle(MiraPalette.secondaryText)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.15), value: state.current)
        .animation(.easeInOut(duration: 0.2), value: state.allPermissionsAnswered)
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshNotificationStatus() }
            }
        }
    }

    // MARK: - Derived

    private var currentMoodLevel: Int {
        switch state.current {
        case .welcome:     return 3
        case .privacy:     return 2
        case .diagnostics: return 4
        case .ai:          return 5
        case .permissions: return 4
        }
    }

    private var backgroundMoods: [Int] {
        let m = currentMoodLevel
        return [m, m == 5 ? 4 : m + 1]
    }

    // MARK: - Pages

    @ViewBuilder
    private var currentPage: some View {
        switch state.current {
        case .welcome:
            OnboardingPage(
                moodLevel: 3,
                stepNumber: 1,
                eyebrowTitle: "Welcome",
                icon: "book.closed",
                title: "Welcome to Mira",
                bodyText: "A private journal where you write what you're going through, track your mood day by day, and let an on-device AI help you reflect — your words never leave the phone."
            )

        case .privacy:
            OnboardingPage(
                moodLevel: 2,
                stepNumber: 2,
                eyebrowTitle: "Privacy",
                icon: "lock.shield",
                title: "Your words stay with you",
                bodyText: "Entries live on your device. iCloud sync, if you turn it on, is end-to-end encrypted."
            )

        case .diagnostics:
            OnboardingPage(
                moodLevel: 4,
                stepNumber: 4,
                eyebrowTitle: "Diagnostics",
                icon: "chart.bar.doc.horizontal",
                title: "Help improve Mira",
                bodyText: "Mira can send anonymous usage events and crash reports so bugs get fixed faster. Your journal entries, photos, and AI prompts never leave your device."
            ) {
                VStack(spacing: 10) {
                    DiagnosticsToggleCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Usage analytics",
                        subtitle: "Which screens are opened and which features are used — no entry text, ever.",
                        moodLevel: 4,
                        isOn: $state.analyticsEnabled
                    )

                    DiagnosticsToggleCard(
                        icon: "ladybug",
                        title: "Crash reports",
                        subtitle: "Stack traces and device info so crashes get tracked down.",
                        moodLevel: 2,
                        isOn: $state.crashReportingEnabled
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

        case .ai:
            OnboardingPage(
                moodLevel: 5,
                stepNumber: 3,
                eyebrowTitle: "Intelligence",
                icon: "sparkles",
                title: "Optional AI",
                bodyText: "A small on-device model runs locally for writing prompts and reflections. Remote providers are opt-in and use your own API key."
            )

        case .permissions:
            OnboardingPage(
                moodLevel: 4,
                stepNumber: 5,
                eyebrowTitle: "Permissions",
                icon: "hand.raised",
                title: "A couple of permissions",
                bodyText: "Notifications let Mira tell you when a reflection is ready. Face ID keeps the app locked when you step away."
            ) {
                VStack(spacing: 10) {
                    PermissionCard(
                        icon: "bell.badge",
                        title: "Allow notifications",
                        subtitle: notificationSubtitle,
                        moodLevel: 4,
                        status: state.notificationStatus,
                        isBusy: isRequestingPermission
                    ) { handleNotificationTap() }

                    PermissionCard(
                        icon: "faceid",
                        title: "Enable Face ID lock",
                        subtitle: biometricSubtitle,
                        moodLevel: 2,
                        status: state.biometricStatus,
                        isBusy: isRequestingPermission
                    ) { Task { await requestBiometric() } }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Dot indicator

    private var dotIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingState.Step.allCases, id: \.rawValue) { step in
                let isCurrent = step == state.current
                Capsule()
                    .fill(isCurrent
                          ? MiraPalette.mood(level: currentMoodLevel)
                          : MiraPalette.primaryText.opacity(0.18))
                    .frame(width: isCurrent ? 22 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: state.current)
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        let isLast = state.current.isLast
        let isDisabled = isLast && !state.allPermissionsAnswered
        return Button {
            // Persist diagnostics consent the moment the user advances
            // past that step — do it before `advance()` so the runtime
            // flip hits Firebase SDKs as early as possible.
            if state.current == .diagnostics {
                persistDiagnosticsConsent()
            }
            if isLast {
                onFinish()
            } else {
                state.advance()
            }
        } label: {
            HStack(spacing: 8) {
                Text(isLast ? "Get started" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: isLast ? "checkmark" : "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText.opacity(isDisabled ? 0.4 : 1))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            Capsule().fill(MiraPalette.mood(level: currentMoodLevel).opacity(isDisabled ? 0.1 : 0.28))
        )
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(isDisabled)
    }

    // MARK: - Derived copy

    private var notificationSubtitle: LocalizedStringKey {
        switch state.notificationStatus {
        case .notAsked: return "So Mira can tell you when a reflection is ready."
        case .granted:  return "Ready — Mira can notify you about reflections."
        case .denied:   return "Blocked. Tap to open Settings and enable notifications."
        }
    }

    private var biometricSubtitle: LocalizedStringKey {
        switch state.biometricStatus {
        case .notAsked: return "Asks for Face ID when you reopen Mira."
        case .granted:  return "On. Mira will ask for Face ID when you reopen it."
        case .denied:   return "Declined. Tap to try again."
        }
    }

    // MARK: - Actions

    private func persistDiagnosticsConsent() {
        var settings = DiagnosticsSettings()
        settings.analyticsEnabled = state.analyticsEnabled
        settings.crashReportingEnabled = state.crashReportingEnabled
        settings.hasAnswered = true
        DiagnosticsSettingsStore().save(settings)
        analyticsService.setEnabled(state.analyticsEnabled)
        crashReporter.setEnabled(state.crashReportingEnabled)
    }

    private func refreshNotificationStatus() async {
        let system = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let mapped: OnboardingState.PermissionStatus = switch system {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .notAsked
        }
        state.setNotificationStatus(mapped)
    }

    private func handleNotificationTap() {
        switch state.notificationStatus {
        case .granted:
            return
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .notAsked:
            Task {
                isRequestingPermission = true
                defer { isRequestingPermission = false }
                let granted = await NotificationService().requestAuthorization()
                // Some iOS builds delay the system-reported status even
                // after the prompt returns. Trust the immediate result
                // first, then refresh for authoritative state.
                state.setNotificationStatus(granted ? .granted : .denied)
                if granted {
                    await MainActor.run {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                await refreshNotificationStatus()
            }
        }
    }

    private func requestBiometric() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        do {
            try await BiometricAuthService().authenticate(
                reason: String(localized: "Enable Face ID lock for Mira"),
                policy: .biometricsOnly
            )
            state.setBiometricStatus(.granted)
            var settings = BiometricSettingsStore().load()
            settings.mode = .soft
            BiometricSettingsStore().save(settings)
        } catch {
            // Declined, cancelled, lockout, etc. — all treated as a
            // conscious "no" for onboarding purposes. The user can retry
            // by tapping the card again, or proceed past the step.
            state.setBiometricStatus(.denied)
        }
    }
}

// MARK: - Page shell

private struct OnboardingPage<Content: View>: View {
    let moodLevel: Int
    let stepNumber: Int
    let eyebrowTitle: LocalizedStringKey
    let icon: String
    let title: LocalizedStringKey
    let bodyText: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    init(
        moodLevel: Int,
        stepNumber: Int,
        eyebrowTitle: LocalizedStringKey,
        icon: String,
        title: LocalizedStringKey,
        bodyText: LocalizedStringKey,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.moodLevel = moodLevel
        self.stepNumber = stepNumber
        self.eyebrowTitle = eyebrowTitle
        self.icon = icon
        self.title = title
        self.bodyText = bodyText
        self.content = content
    }

    var body: some View {
        VStack(spacing: 28) {
            medallion

            VStack(spacing: 14) {
                eyebrow

                Text(title)
                    .font(MiraTypography.hero)
                    .foregroundStyle(MiraPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyText)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            content()
        }
    }

    private var medallion: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    MiraPalette.mood(level: moodLevel).opacity(0.22),
                    lineWidth: 1
                )
                .frame(width: 140, height: 140)
            Circle()
                .fill(MiraPalette.mood(level: moodLevel).opacity(0.20))
                .frame(width: 104, height: 104)
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.88))
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", stepNumber))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MiraPalette.mood(level: moodLevel).opacity(0.9))
                .tracking(1.2)
            Circle()
                .fill(MiraPalette.secondaryText.opacity(0.35))
                .frame(width: 3, height: 3)
            Text(eyebrowTitle)
                .eyebrowStyle()
        }
    }
}

// MARK: - Permission card

private struct PermissionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let moodLevel: Int
    let status: OnboardingState.PermissionStatus
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(iconBubbleOpacity)))

                VStack(alignment: .leading, spacing: 4) {
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

                trailingIndicator
                    .padding(.top, 10)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if status == .granted {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MiraPalette.mood(level: moodLevel).opacity(0.08))
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if status == .granted {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(MiraPalette.mood(level: moodLevel).opacity(0.4), lineWidth: 1.5)
                }
            }
            .opacity(isBusy && status != .granted ? 0.6 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.2), value: status)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || status == .granted)
        .sensoryFeedback(.success, trigger: status == .granted)
    }

    private var iconBubbleOpacity: CGFloat {
        switch status {
        case .granted:  return 0.3
        case .denied:   return 0.10
        case .notAsked: return 0.15
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MiraPalette.mood(level: moodLevel))
                .transition(.scale.combined(with: .opacity))
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.45))
                .transition(.scale.combined(with: .opacity))
        case .notAsked:
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Diagnostics toggle card

private struct DiagnosticsToggleCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let moodLevel: Int
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(isOn ? 0.30 : 0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MiraPalette.mood(level: moodLevel))
                .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isOn {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MiraPalette.mood(level: moodLevel).opacity(0.08))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if isOn {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(MiraPalette.mood(level: moodLevel).opacity(0.4), lineWidth: 1.5)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isOn)
    }
}
