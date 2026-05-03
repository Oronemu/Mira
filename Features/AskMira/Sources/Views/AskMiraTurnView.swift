import SwiftUI
import CoreKit
import DesignSystem

/// Renders a single Q/A turn in the AskMira conversation. Used for both
/// completed turns (`snapshot:`) and the in-flight streaming turn
/// (`streaming:`).
struct AskMiraTurnView: View {
    enum Source {
        case snapshot(AskMiraTurnSnapshot)
        case streaming(question: String, answer: String, referenceIDs: [UUID])
    }

    let source: Source
    let onSelectReference: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !question.isEmpty {
                QuestionBubble(text: question)
            }
            AnswerBubble(text: answer, isStreamingEmpty: isStreamingEmpty)
            if !referenceIDs.isEmpty {
                ReferenceRow(ids: referenceIDs, onSelect: onSelectReference)
            }
        }
    }

    private var question: String {
        switch source {
        case .snapshot(let s): s.question
        case .streaming(let q, _, _): q
        }
    }

    private var answer: String {
        switch source {
        case .snapshot(let s): s.answer
        case .streaming(_, let a, _): a
        }
    }

    private var referenceIDs: [UUID] {
        switch source {
        case .snapshot(let s): s.referencedEntryIDs
        case .streaming(_, _, let ids): ids
        }
    }

    private var isStreamingEmpty: Bool {
        switch source {
        case .snapshot: false
        case .streaming(_, let a, _): a.isEmpty
        }
    }
}

// MARK: - Question bubble

private struct QuestionBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("You").eyebrowStyle()
            Text(text)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 40)
    }
}

// MARK: - Answer bubble

private struct AnswerBubble: View {
    let text: String
    let isStreamingEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mira").eyebrowStyle()
            if isStreamingEmpty {
                HStack(spacing: 10) {
                    TypingIndicator()
                    Text("Thinking…")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            } else {
                Text(attributedAnswer)
                    .font(MiraTypography.entryBody)
                    .foregroundStyle(MiraPalette.primaryText)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    /// Parse markdown from the model's answer. Inline-only preserves newlines
    /// during streaming and avoids block-level reflow mid-token. Falls back to
    /// the raw string if parsing fails.
    private var attributedAnswer: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

// MARK: - Typing indicator

/// Three pulsing dots driven by a `TimelineView`. We compute scale/opacity
/// directly from elapsed time rather than driving them through an
/// `.animation(.repeatForever(...))` on a `@State` toggle — the latter
/// would overshoot its original amplitude after a tab-switch teardown
/// because the freshly-mounted view's implicit animation collides with a
/// still-resolving prior transaction. Time-based computation is
/// stateless, so view recreation resumes seamlessly from "now".
private struct TypingIndicator: View {
    private static let cycleSeconds: Double = 1.4
    private static let staggerSeconds: Double = 0.18
    private static let moodLevels: [Int] = [2, 3, 5]

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    dot(index: index, at: timeline.date)
                }
            }
        }
    }

    private func dot(index: Int, at date: Date) -> some View {
        // Sine wave eased between 0…1 so the dot pulses smoothly without
        // a discrete autoreverse boundary that the SwiftUI animation
        // engine could reorder mid-flight.
        let elapsed = date.timeIntervalSinceReferenceDate - Double(index) * Self.staggerSeconds
        let progress = elapsed.truncatingRemainder(dividingBy: Self.cycleSeconds) / Self.cycleSeconds
        let wave = (sin(progress * 2 * .pi - .pi / 2) + 1) / 2
        let scale = 0.55 + wave * 0.45
        let opacity = 0.4 + wave * 0.6
        return Circle()
            .fill(MiraPalette.mood(level: Self.moodLevels[index]))
            .frame(width: 7, height: 7)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

// MARK: - Reference row

private struct ReferenceRow: View {
    let ids: [UUID]
    let onSelect: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(ids.enumerated()), id: \.offset) { index, id in
                    ReferenceChip(index: index + 1) { onSelect(id) }
                }
            }
        }
        .padding(.leading, 2)
    }
}

private struct ReferenceChip: View {
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.system(size: 9, weight: .semibold))
                Text("[\(index)]")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(MiraPalette.primaryText.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(MiraPalette.mood(level: 3).opacity(0.20)))
            .overlay(Capsule().strokeBorder(MiraPalette.mood(level: 3).opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
