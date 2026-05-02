import SwiftUI
import CoreKit
import Utilities
import AIKit
import DesignSystem

public struct PrivacySettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.openURL) private var openURL
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @State private var state: SettingsState?

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [2, 3], intensity: 0.55)

            Group {
                if let state {
                    content(state: state)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Privacy")
        .task {
            if state == nil {
                state = SettingsState(
                    service: aiService,
                    entryRepository: entryRepository,
                    insightRepository: insightRepository,
                    coordinator: coordinator,
                    analyticsService: analyticsService,
                    crashReporter: crashReporter
                )
            }
            await state?.refresh()
        }
    }

    private func content(state: SettingsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHero(
                    title: "Privacy",
                    subtitle: "Who can open Mira on this device"
                )

                VStack(spacing: 10) {
                    SettingsOptionCard(
                        icon: "lock.open",
                        title: "Off",
                        subtitle: "Mira opens freely. Use when your device already requires a passcode.",
                        moodLevel: 3,
                        isSelected: state.biometric.mode == .off,
                        isEnabled: state.isBiometricAvailable
                    ) { state.setBiometricMode(.off) }

                    SettingsOptionCard(
                        icon: "lock.badge.clock",
                        title: "Soft",
                        subtitle: "Asks for Face ID / passcode only after 60 seconds in the background.",
                        moodLevel: 4,
                        isSelected: state.biometric.mode == .soft,
                        isEnabled: state.isBiometricAvailable
                    ) { state.setBiometricMode(.soft) }

                    SettingsOptionCard(
                        icon: "lock.fill",
                        title: "Always",
                        subtitle: "Locks on every launch. The strongest protection.",
                        moodLevel: 1,
                        isSelected: state.biometric.mode == .always,
                        isEnabled: state.isBiometricAvailable
                    ) { state.setBiometricMode(.always) }
                }
                .animation(.spring(duration: 0.35, bounce: 0.2), value: state.biometric.mode)

                if state.isBiometricAvailable {
                    biometricHint
                } else {
                    ErrorPill("Biometric authentication is not set up on this device.")
                }

                SettingsHero(
                    title: "Screen shield",
                    subtitle: "What others see when you switch apps"
                )
                .padding(.top, 8)

                screenShieldCard(state: state)

                SettingsHero(
                    title: "Diagnostics & analytics",
                    subtitle: "Help improve Mira — journal content is never included"
                )
                .padding(.top, 8)

                diagnosticsSection(state: state)

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var biometricHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MiraPalette.secondaryText)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("If you declined Face ID for Mira, the lock will ask for your device passcode. To use Face ID, enable it for Mira in iOS Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Open iOS Settings")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(MiraPalette.mood(level: 4))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func diagnosticsSection(state: SettingsState) -> some View {
        VStack(spacing: 10) {
            diagnosticsRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Usage analytics",
                subtitle: "Anonymous screen views and feature counters. No entry content.",
                moodLevel: 4,
                isOn: Binding(
                    get: { state.diagnostics.analyticsEnabled },
                    set: { state.setAnalyticsEnabled($0) }
                )
            )

            diagnosticsRow(
                icon: "ladybug",
                title: "Crash reports",
                subtitle: "Stack traces and device info for fixing crashes.",
                moodLevel: 2,
                isOn: Binding(
                    get: { state.diagnostics.crashReportingEnabled },
                    set: { state.setCrashReportingEnabled($0) }
                )
            )
        }
    }

    private func diagnosticsRow(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        moodLevel: Int,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(isOn.wrappedValue ? 0.28 : 0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(MiraPalette.mood(level: moodLevel))
                .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func screenShieldCard(state: SettingsState) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "eye.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: 2).opacity(0.18)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Hide content in app switcher")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text("Blurs your journal while you swipe between apps.")
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { state.screenShield.isEnabled },
                set: { state.setScreenShieldEnabled($0) }
            ))
            .labelsHidden()
            .tint(MiraPalette.mood(level: 2))
            .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
