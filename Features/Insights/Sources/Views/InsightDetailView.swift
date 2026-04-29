import SwiftUI
import CoreKit
import DesignSystem

public struct InsightDetailView: View {
    @Environment(\.insightRepository) private var repository
    @Environment(\.entryRepository) private var entryRepository

    @State private var insight: InsightSnapshot?
    @State private var referenced: [EntrySnapshot] = []
    @State private var isLoading: Bool = true

    private let insightID: UUID
    private let onSelectEntry: (UUID) -> Void

    public init(insightID: UUID, onSelectEntry: @escaping (UUID) -> Void) {
        self.insightID = insightID
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.65)

            if let insight {
                scroll(insight: insight)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                notFound
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
    }

    // MARK: - Scroll

    private func scroll(insight: InsightSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(insight)

                Text(attributedBody(insight.body))
                    .font(MiraTypography.entryBody)
                    .foregroundStyle(MiraPalette.primaryText)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !referenced.isEmpty {
                    referencedSection
                }

                Color.clear.frame(height: 48)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private func header(_ insight: InsightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(insight.createdAt, format: .dateTime.day().month(.wide).year())
                .eyebrowStyle()
            Text(insight.title)
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: - Referenced

    private var referencedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Referenced entries").eyebrowStyle()
            VStack(spacing: 10) {
                ForEach(Array(referenced.enumerated()), id: \.element.id) { index, entry in
                    ReferenceCard(index: index + 1, entry: entry) {
                        onSelectEntry(entry.id)
                    }
                }
            }
        }
    }

    // MARK: - Not found

    private var notFound: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            Text("Not found")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text("This reflection may have been deleted.")
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Derived

    /// Ambient takes on the moods of the entries the reflection is about —
    /// lets the screen feel emotionally anchored to the period being
    /// reflected on rather than the day the reflection was written.
    private var ambientMoodLevels: [Int] {
        let moods = referenced.compactMap(\.mood).map(\.rawValue)
        return moods.isEmpty ? [3] : moods
    }

    // MARK: - Markdown

    /// AI reflections sometimes include markdown (**bold**, *italic*, etc.).
    /// Render it as an AttributedString; fall back to the raw text on parse
    /// failure.
    private func attributedBody(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let snapshot = try? await repository.fetch(id: insightID) else { return }
        insight = snapshot
        var loaded: [EntrySnapshot] = []
        for id in snapshot.referencedEntryIDs {
            if let entry = try? await entryRepository.fetch(id: id) {
                loaded.append(entry)
            }
        }
        referenced = loaded
    }
}

// MARK: - Reference card

private struct ReferenceCard: View {
    let index: Int
    let entry: EntrySnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                MoodAccent(level: entry.mood?.rawValue)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("[\(index)]")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MiraPalette.secondaryText)
                        Text(entry.createdAt, format: .dateTime.day().month(.abbreviated).year())
                            .eyebrowStyle()
                    }
                    Text(entry.content)
                        .font(MiraTypography.entryBody)
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                        .lineSpacing(2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.top, 4)
            }
            .padding(14)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                if let level = entry.mood?.rawValue {
                    shape.fill(MiraPalette.mood(level: level).opacity(0.07))
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PressableCardStyle())
    }
}
