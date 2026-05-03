import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Pro teaser card on Stats — a single-line summary of the user's
/// year so far, plus a chevron that pushes `YearInReviewView` for the
/// full breakdown.
struct YearInReviewCard: View {
    let report: StatisticsCalculator.YearReport

    var body: some View {
        NavigationLink {
            YearInReviewView(report: report)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(MiraPalette.mood(level: 4).opacity(0.18)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(report.year)) in review", comment: "Year-in-review card title")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(summary)
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var summary: String {
        if report.totalEntries == 0 {
            return String(localized: "Start writing to see your year unfold.")
        }
        let avg = report.averageMood.map { String(format: "%.1f", $0) } ?? "—"
        return String(
            format: String(localized: "%lld entries · %lld words · avg mood %@"),
            report.totalEntries,
            report.totalWords,
            avg
        )
    }
}
