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

                    // Tab bar footprint — keep the contact card clear of
                    // the Liquid Glass tab bar at the bottom of the app.
                    Color.clear.frame(height: 110)
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
            answer: String(localized: "On your iPhone. Your journal stays on this device. If you turn on iCloud sync, your entries also save to your private iCloud — only you can read them. When you ask Mira a question with cloud AI, only that question and a small relevant piece of your journal go to our servers; everything else stays on the phone.")
        ),
        FAQItem(
            id: "free-vs-pro",
            question: String(localized: "What's the difference between free and Pro?"),
            answer: String(localized: "Free gives you the full journal: writing, mood, photos, tags, calendar, search, iCloud sync, biometric lock, and a local AI for reflections. Pro unlocks Ask Mira with cloud AI, advanced stats, themes and icons, PDF export, your own AI persona, smart filters, goals and habits, Lock Screen widgets, and importers from other journal apps.")
        ),
        FAQItem(
            id: "trial",
            question: String(localized: "How does the free trial work?"),
            answer: String(localized: "Pro starts with a 7-day free trial. You won't be charged until the trial ends. Cancel any time during the trial — you'll keep Pro until the trial expires, then drop back to free with no charge.")
        ),
        FAQItem(
            id: "cancel",
            question: String(localized: "How do I cancel my subscription?"),
            answer: String(localized: "Open the iPhone Settings app, tap your name at the top, choose Subscriptions, tap Mira Pro, and Cancel Subscription. Your Pro features stay active until the end of the current billing period.")
        ),
        FAQItem(
            id: "restore",
            question: String(localized: "I bought Pro on another device — how do I restore it here?"),
            answer: String(localized: "Open the upgrade screen and tap Restore at the bottom. Make sure you're signed into the same Apple ID you used when you subscribed.")
        ),
        FAQItem(
            id: "ai-limits",
            question: String(localized: "Are there limits on Ask Mira?"),
            answer: String(localized: "Pro includes 100 cloud conversations per month and 2 manual weekly reflections. Automatic weekly reflections don't count. Limits reset on the 1st of each month. The local AI option has no limits and runs entirely on your phone — switch in Settings → Intelligence.")
        ),
        FAQItem(
            id: "icloud-sync",
            question: String(localized: "How does iCloud sync work?"),
            answer: String(localized: "Turn on iCloud sync and your entries quietly save to your private iCloud, encrypted so only your devices can read them. Sign into the same Apple ID on another iPhone and Mira will pick everything up automatically.")
        ),
        FAQItem(
            id: "redeem",
            question: String(localized: "I have a promo code — how do I redeem it?"),
            answer: String(localized: "Open the upgrade screen and tap Redeem code at the bottom. Enter the code — capital letters and extra spaces don't matter — and tap Redeem. If it's valid, Pro unlocks right away.")
        ),
        FAQItem(
            id: "delete",
            question: String(localized: "Can I delete all my data?"),
            answer: String(localized: "Yes. Settings → Privacy → Delete all entries removes everything from this iPhone. If iCloud sync is on, the deletion also reaches your other devices the next time they sync. If you'd also like us to clear any record of your subscription on our side, write to support.")
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
                        .transition(.opacity)
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
            // Clip so the answer fades inside the card rather than
            // bleeding past the rounded edge during the collapse
            // animation.
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
