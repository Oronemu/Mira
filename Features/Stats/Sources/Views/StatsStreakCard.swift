import SwiftUI
import Utilities
import DesignSystem

/// Two-column streak summary. Left column: a soft mood-colored ring with
/// the current-streak number centered in serif. Right column: the
/// long-term best streak with the date it began.
struct StatsStreakCard: View {
    let streak: Utilities.StatisticsCalculator.Streak
    let moodLevel: Int

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ring
            divider
            details
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(MiraPalette.primaryText.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    MiraPalette.mood(level: moodLevel),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5, bounce: 0.15), value: progress)
            VStack(spacing: 0) {
                Text("\(streak.current)")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text("days", comment: "Stats — streak ring caption (short, fits inside 88pt circle)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
        .frame(width: 88, height: 88)
    }

    private var progress: Double {
        guard streak.best > 0 else { return 0 }
        return min(1, Double(streak.current) / Double(streak.best))
    }

    private var divider: some View {
        Rectangle()
            .fill(MiraPalette.primaryText.opacity(0.06))
            .frame(width: 1, height: 60)
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Best so far", comment: "Stats — best-streak label")
                .eyebrowStyle()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(streak.best)")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text("days", comment: "Stats — unit label after a streak count")
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
            if let start = streak.bestStartDate {
                Text(
                    "since \(start.formatted(.dateTime.month(.abbreviated).day()))",
                    comment: "Stats — when the best streak began (e.g. since Apr 2)"
                )
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
