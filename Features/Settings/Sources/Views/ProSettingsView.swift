import SwiftUI
import CoreKit
import Utilities
import DesignSystem
import StoreKit

/// Mira Pro management screen. Reachable via the upgrade banner in the
/// Settings root: free users see an "Unlock Pro" CTA that raises the
/// paywall, paying customers see their plan, renewal date, and entry
/// points to App Store management, restore, and redeem-code flows.
public struct ProSettingsView: View {
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @Environment(\.legalLinks) private var legalLinks
    @Environment(\.openURL) private var openURL

    @State private var status: CoreKit.SubscriptionStatus = .unknown
    @State private var isRestoring = false
    @State private var feedback: String?
    @State private var showingOfferCodeSheet = false
    @State private var usage: UsageLoad = .idle

    private enum UsageLoad: Equatable {
        case idle
        case loading
        case loaded(CoreKit.UsageSnapshot)
        case failed(String)
    }

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [4, 5], intensity: 0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusCard
                    usageCard
                    actionsList
                    if let feedback {
                        Text(feedback)
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    footer
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            .refreshable { await loadUsage() }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .collapsibleHeroTitle("Mira Pro")
        .task {
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
        .task(id: status.isPro) {
            // Load monthly usage when (and only when) the user is Pro.
            // Status flipping back to free clears the section so a
            // canceled subscription doesn't leave stale "12 / 100 left"
            // copy on screen.
            if status.isPro {
                await loadUsage()
            } else {
                usage = .idle
            }
        }
        .offerCodeRedemption(isPresented: $showingOfferCodeSheet) { result in
            // Apple's redeem sheet drives the StoreKit transaction flow
            // directly. The bootstrap listener in `StoreKitSubscriptionService`
            // refreshes `status`, so success has no work to do here. On
            // failure surface a short message under the actions list.
            switch result {
            case .success:
                feedback = nil
            case .failure(let error):
                feedback = error.localizedDescription
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusCard: some View {
        switch status {
        case .pro(let pro):
            activeCard(pro: pro)
        case .free, .unknown:
            unlockCard
        }
    }

    private func activeCard(pro: CoreKit.SubscriptionStatus.Pro) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.tint)
                Text(String(localized: "Active"))
                    .font(MiraTypography.headline)
            }

            Text(planTitle(pro: pro))
                .font(MiraTypography.body)
                .foregroundStyle(.secondary)

            if let renewal = pro.renewalDate {
                Text(renewalCopy(date: renewal, isInTrial: pro.isInTrial))
                    .font(MiraTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Text(sourceCopy(source: pro.source))
                .font(MiraTypography.caption)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.tint.opacity(0.08))
        )
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text(String(localized: "Mira Pro"))
                    .font(MiraTypography.headline)
            }

            Text(String(localized: "Unlock hosted Ask Mira, advanced analytics, themes, PDF templates, smart filters, and more."))
                .font(MiraTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(String(localized: "Unlock Pro")) {
                paywallPresenter.present(.general)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.mood(level: 5).opacity(0.18))
        )
    }

    // MARK: - Usage

    /// Monthly usage of the metered hosted-AI intents. Free or unknown
    /// users don't see this section at all — it would expose limits
    /// they can't act on. Pull-to-refresh on the surrounding ScrollView
    /// reissues the fetch.
    @ViewBuilder
    private var usageCard: some View {
        if status.isPro {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "This month"))
                    .eyebrowStyle()

                switch usage {
                case .idle, .loading:
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "Loading usage…"))
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                case .loaded(let snapshot):
                    usageRow(
                        title: String(localized: "Ask Mira"),
                        dimension: snapshot.askMira
                    )
                    usageRow(
                        title: String(localized: "Weekly Reflection"),
                        dimension: snapshot.manualReflections
                    )
                    Text(resetsCopy(periodEnd: snapshot.periodEnd))
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                        Text(message)
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.thinMaterial)
            )
        }
    }

    private func usageRow(title: String, dimension: CoreKit.UsageSnapshot.Dimension) -> some View {
        // Fraction = used / limit so the bar fills as the user spends.
        // Clamp to [0, 1] in case an upstream count somehow overflows.
        let fraction: Double = dimension.limit > 0
            ? min(1.0, Double(dimension.used) / Double(dimension.limit))
            : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(MiraTypography.body)
                    .foregroundStyle(MiraPalette.primaryText)
                Spacer(minLength: 8)
                Text(remainingCopy(remaining: dimension.remaining, limit: dimension.limit))
                    .font(MiraTypography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
        }
    }

    private func remainingCopy(remaining: Int, limit: Int) -> String {
        String(
            format: String(localized: "%lld of %lld left this month"),
            remaining,
            limit
        )
    }

    private func resetsCopy(periodEnd: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return String(
            format: String(localized: "Resets on %@"),
            formatter.string(from: periodEnd)
        )
    }

    private func loadUsage() async {
        guard status.isPro else {
            usage = .idle
            return
        }
        usage = .loading
        do {
            let snapshot = try await subscriptionService.fetchUsage()
            usage = .loaded(snapshot)
        } catch {
            usage = .failed(error.localizedDescription)
        }
    }

    private var actionsList: some View {
        VStack(spacing: 10) {
            actionRow(
                icon: "creditcard",
                title: String(localized: "Manage subscription"),
                subtitle: String(localized: "Open this app's page in App Store settings.")
            ) { openManagement() }

            actionRow(
                icon: "arrow.clockwise",
                title: isRestoring
                    ? String(localized: "Restoring…")
                    : String(localized: "Restore purchases"),
                subtitle: String(localized: "Recover Pro on a new device using the same Apple ID.")
            ) { Task { await restore() } }
            .disabled(isRestoring)

            actionRow(
                icon: "ticket",
                title: String(localized: "Redeem a code"),
                subtitle: String(localized: "Apply an offer code from the App Store.")
            ) { showingOfferCodeSheet = true }
        }
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MiraPalette.mood(level: 3).opacity(0.18)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MiraTypography.headline)
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(subtitle)
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Subscriptions auto-renew until cancelled in App Store settings at least 24 hours before the end of the current period."))
            HStack(spacing: 16) {
                Button(String(localized: "Privacy")) {
                    openURL(legalLinks.privacyURL)
                }
                Button(String(localized: "Terms")) {
                    openURL(legalLinks.termsURL)
                }
            }
            .font(MiraTypography.caption.weight(.semibold))
            .foregroundStyle(.tint)
        }
        .font(MiraTypography.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func restore() async {
        feedback = nil
        isRestoring = true
        defer { isRestoring = false }
        do {
            let restored = try await subscriptionService.restorePurchases()
            feedback = restored.isPro
                ? String(localized: "Pro restored.")
                : String(localized: "No active subscription found for this Apple ID.")
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func openManagement() {
        Task {
            do {
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first {
                    try await AppStore.showManageSubscriptions(in: scene)
                }
            } catch {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Copy helpers

    private func planTitle(pro: CoreKit.SubscriptionStatus.Pro) -> String {
        switch pro.plan {
        case .monthly: String(localized: "Monthly plan")
        case .yearly: String(localized: "Yearly plan")
        }
    }

    private func renewalCopy(date: Date, isInTrial: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let formatted = formatter.string(from: date)
        return isInTrial
            ? String(format: String(localized: "Free trial through %@"), formatted)
            : String(format: String(localized: "Renews on %@"), formatted)
    }

    private func sourceCopy(source: CoreKit.SubscriptionStatus.Pro.Source) -> String {
        switch source {
        case .appStore: String(localized: "Subscribed via App Store")
        case .testFlight: String(localized: "TestFlight build — Pro granted automatically")
        case .redeemCode: String(localized: "Granted via redemption code")
        case .appleOfferCode: String(localized: "Activated via App Store offer code")
        }
    }
}
