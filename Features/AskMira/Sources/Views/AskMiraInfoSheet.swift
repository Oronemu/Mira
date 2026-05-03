import SwiftUI
import DesignSystem

/// "About Mira" sheet shown from the leading toolbar button on the
/// AskMira screen. Explains the companion's role, how it works, the
/// privacy posture, and — prominently — the medical/professional
/// disclaimer.
public struct AskMiraInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        MiraSheetChrome(moodLevels: [3, 4], intensity: 0.4) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero

                        section(
                            title: String(localized: "Who I am"),
                            body: String(localized: "I'm a quiet companion that reads your journal so I can understand you. Not a record-keeper — an attentive friend who listens and responds.")
                        )

                        section(
                            title: String(localized: "How I help"),
                            bullets: [
                                String(localized: "Answer questions about your life, using what you've written"),
                                String(localized: "Notice patterns and themes in your entries"),
                                String(localized: "Offer a gentle, grounded perspective"),
                                String(localized: "Help you put a feeling into words"),
                            ]
                        )

                        section(
                            title: String(localized: "How I work"),
                            bullets: [
                                String(localized: "I only remember this conversation — other chats stay separate"),
                                String(localized: "I look through your journal before replying"),
                            ]
                        )

                        section(
                            title: String(localized: "Your privacy"),
                            bullets: [
                                String(localized: "I never share what you write with anyone"),
                                String(localized: "Your entries and photos stay on your phone"),
                                String(localized: "If you turn on iCloud backup, it stays encrypted"),
                            ]
                        )

                        disclaimerCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .navigationTitle("")
                .toolbarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MiraPalette.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Close"))
                    }
                }
            }
        }
        .miraSheet([.large])
    }

    // MARK: - Subviews

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask Mira")
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)

            Text("A private conversation with your journal")
                .eyebrowStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrowStyle()
            Text(body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(MiraPalette.mood(level: 4))
                        Text(item)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(MiraPalette.primaryText.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: 2))
                Text("Disclaimer")
                    .font(MiraTypography.headline)
                    .foregroundStyle(MiraPalette.primaryText)
            }

            Text("I'm not a therapist or a doctor. My replies can be wrong — please don't take them as professional advice. If you're going through a hard time, reach out to a qualified specialist or local emergency services.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.mood(level: 2).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MiraPalette.mood(level: 2).opacity(0.35), lineWidth: 1)
        )
        .padding(.top, 8)
    }

}
