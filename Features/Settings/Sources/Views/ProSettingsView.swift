import SwiftUI
import CoreKit
import DesignSystem
import StoreKit

/// Mira Pro management screen. Reachable via the upgrade banner in the
/// Settings root: free users see an "Unlock Pro" CTA that raises the
/// paywall, paying customers see their plan, renewal date, and entry
/// points to App Store management, restore, and redeem-code flows.
public struct ProSettingsView: View {
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @Environment(\.openURL) private var openURL

    @State private var status: SubscriptionStatus = .unknown
    @State private var isRestoring = false
    @State private var feedback: String?
    @State private var showingRedeem = false
    @State private var redeemCode = ""

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [4, 5], intensity: 0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusCard
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
        .sheet(isPresented: $showingRedeem) {
            redeemSheet
                .presentationDetents([.medium])
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

    private func activeCard(pro: SubscriptionStatus.Pro) -> some View {
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
                subtitle: String(localized: "Apply a complimentary or beta access code.")
            ) { showingRedeem = true }
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
                    if let url = URL(string: "https://mira.app/privacy") { openURL(url) }
                }
                Button(String(localized: "Terms")) {
                    if let url = URL(string: "https://mira.app/terms") { openURL(url) }
                }
            }
            .font(MiraTypography.caption.weight(.semibold))
            .foregroundStyle(.tint)
        }
        .font(MiraTypography.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Redeem sheet

    private var redeemSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Code"), text: $redeemCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } footer: {
                    Text(String(localized: "Codes are issued for testing, beta access, or as gifts."))
                }

                if let feedback {
                    Section { Text(feedback).font(MiraTypography.caption) }
                }
            }
            .navigationTitle(String(localized: "Redeem a code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { showingRedeem = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Redeem")) {
                        Task { await redeem() }
                    }
                    .disabled(redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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

    private func redeem() async {
        let code = redeemCode.trimmingCharacters(in: .whitespacesAndNewlines)
        feedback = nil
        do {
            let result = try await subscriptionService.redeem(code: code)
            if result.isPro {
                redeemCode = ""
                showingRedeem = false
                feedback = String(localized: "Pro unlocked.")
            }
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

    private func planTitle(pro: SubscriptionStatus.Pro) -> String {
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

    private func sourceCopy(source: SubscriptionStatus.Pro.Source) -> String {
        switch source {
        case .appStore: String(localized: "Subscribed via App Store")
        case .testFlight: String(localized: "TestFlight build — Pro granted automatically")
        case .redeemCode: String(localized: "Granted via redemption code")
        case .appleOfferCode: String(localized: "Activated via App Store offer code")
        }
    }
}
