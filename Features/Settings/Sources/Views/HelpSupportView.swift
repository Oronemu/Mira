import SwiftUI
import CoreKit
import DesignSystem

/// FAQ + email support page reachable from Settings. Questions are
/// authored in code (not loaded from the network) so the page works
/// offline and ships with the app — important since Mira's whole
/// premise is "no network needed for the journal." When a user has a
/// question that isn't covered, the bottom CTA opens a pre-filled
/// mailto: with version metadata so support replies don't have to ask
/// "what build are you on?".
public struct HelpSupportView: View {
    @Environment(\.openURL) private var openURL

    private static let supportEmail = "arbuzikmr@gmail.com"

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    VStack(spacing: 10) {
                        ForEach(Self.faqs) { item in
                            FAQRow(item: item)
                        }
                    }

                    contactCard

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Help & support"))
                .eyebrowStyle()
            Text(String(localized: "How can we help?"))
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            Text(String(localized: "A few common questions. If yours isn't here, write to us — every email is read by a human."))
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(MiraPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    // MARK: - Contact

    private var contactCard: some View {
        Button {
            if let url = mailtoURL { openURL(url) }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MiraPalette.mood(level: 4).opacity(0.22))
                    Image(systemName: "envelope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MiraPalette.mood(level: 4))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Email support"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(Self.supportEmail)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(MiraPalette.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MiraPalette.surfaceElevated.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(MiraPalette.divider, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    /// Pre-fills subject with version + build metadata so first reply
    /// can skip the "what build are you on" round-trip.
    private var mailtoURL: URL? {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let subject = "Mira support — v\(version) (\(build))"
        guard let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return URL(string: "mailto:\(Self.supportEmail)")
        }
        return URL(string: "mailto:\(Self.supportEmail)?subject=\(encoded)")
    }

    // MARK: - FAQ data

    /// Curated list — keep under ~10 entries so the page stays scannable.
    /// Order is by perceived frequency: privacy first (Mira's headline
    /// promise), then subscription mechanics (Apple-mandated visibility),
    /// then feature questions.
    private static let faqs: [FAQItem] = [
        FAQItem(
            id: "privacy",
            question: String(localized: "Where do my entries live?"),
            answer: String(localized: "On your device. Mira stores everything in a local SwiftData database. iCloud sync, when you turn it on, copies the data end-to-end encrypted to your private iCloud — Apple can't read it, we can't read it. Pro hosted AI sends only the message text and a small RAG-selected slice of your journal to our proxy when you ask Mira a question; the rest of the journal never leaves your phone.")
        ),
        FAQItem(
            id: "free-vs-pro",
            question: String(localized: "What's the difference between free and Pro?"),
            answer: String(localized: "Free covers the journal itself: writing, mood, photos, tags, calendar, search, iCloud sync, biometric lock, on-device Apple Foundation Models AI. Pro adds Ask Mira (Claude conversations), advanced stats, themes and app icons, PDF export, custom AI personas, smart filters, goals & habits, Lock Screen widgets, and importers from Day One / Apple Notes.")
        ),
        FAQItem(
            id: "trial",
            question: String(localized: "How does the free trial work?"),
            answer: String(localized: "Pro starts with a 7-day free trial. You won't be charged until the trial ends. Cancel any time during the trial in iOS Settings → Apple ID → Subscriptions and you'll keep Pro until the trial expires, then drop back to free with no charge.")
        ),
        FAQItem(
            id: "cancel",
            question: String(localized: "How do I cancel my subscription?"),
            answer: String(localized: "Open the iOS Settings app → tap your name at the top → Subscriptions → Mira Pro → Cancel Subscription. Apple processes the cancellation; we don't store payment info. Your Pro features stay active until the end of the current billing period.")
        ),
        FAQItem(
            id: "restore",
            question: String(localized: "I bought Pro on another device — how do I restore it here?"),
            answer: String(localized: "Open the paywall (Settings → Upgrade or any locked feature) and tap Restore at the bottom. Apple will look up your purchase against your Apple ID and unlock Pro on this device. Make sure you're signed into the same Apple ID you used to subscribe.")
        ),
        FAQItem(
            id: "ai-limits",
            question: String(localized: "Are there limits on Ask Mira?"),
            answer: String(localized: "Pro includes 100 Ask Mira conversations per calendar month and 2 manually-triggered weekly reflections. Auto-fired weekly reflections aren't counted. Limits reset on the 1st. The on-device Apple Foundation Models option has no limit and runs entirely on your phone — toggle it in Settings → Intelligence.")
        ),
        FAQItem(
            id: "icloud-sync",
            question: String(localized: "How does iCloud sync work?"),
            answer: String(localized: "When enabled, Mira encrypts each entry on this device using a key stored in your iCloud Keychain, then uploads the ciphertext to your private iCloud database. Other devices signed into the same Apple ID download and decrypt locally. Apple sees only encrypted blobs — they don't have the key.")
        ),
        FAQItem(
            id: "redeem",
            question: String(localized: "I have a promo code — how do I redeem it?"),
            answer: String(localized: "Open the paywall and tap Redeem code at the bottom. Enter the code and tap Redeem. If it's valid you'll be unlocked immediately. Codes are case-insensitive and trimmed of surrounding spaces.")
        ),
        FAQItem(
            id: "delete",
            question: String(localized: "Can I delete all my data?"),
            answer: String(localized: "Yes. Settings → Privacy → Delete all entries removes everything from this device. If iCloud sync is on, the deletion propagates to your other devices on next sync. To also revoke any cached subscription state on our backend, write to support and we'll wipe your originalTransactionId from our records.")
        ),
    ]

    private struct FAQItem: Identifiable {
        let id: String
        let question: String
        let answer: String
    }

    /// Glass-tinted disclosure card. Tap toggles the answer with a quiet
    /// spring; a chevron rotates to signal state. Each card carries its
    /// own @State so multiple can be open simultaneously.
    private struct FAQRow: View {
        let item: FAQItem
        @State private var expanded = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(duration: 0.32, bounce: 0.12)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(item.question)
                            .font(.system(size: 15.5, weight: .semibold, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MiraPalette.secondaryText)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(item.answer)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MiraPalette.surfaceElevated.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(MiraPalette.divider, lineWidth: 0.5)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
