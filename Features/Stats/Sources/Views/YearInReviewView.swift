import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Full Year-in-Review screen, pushed from the YearInReviewCard on
/// Stats. Renders a hero with the year, headline counters, mood
/// distribution bars, the best month, top tags, and the longest
/// streak. All from the supplied `YearReport` — no fetching here.
struct YearInReviewView: View {
    let report: StatisticsCalculator.YearReport

    private var ambientLevel: Int {
        guard let avg = report.averageMood else { return 3 }
        return max(1, min(5, Int(round(avg))))
    }

    var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [ambientLevel], intensity: 0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    if report.totalEntries == 0 {
                        emptyState
                    } else {
                        countersRow
                        moodDistributionCard
                        if let best = report.bestMonth {
                            bestMonthCard(best)
                        }
                        if !report.topTags.isEmpty {
                            topTagsCard
                        }
                        streakCard
                    }

                    Color.clear.frame(height: 64)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Year in review")
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YEAR IN REVIEW · \(String(report.year))").eyebrowStyle()
            Text("How \(String(report.year)) shaped you")
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        Text("No entries yet for this year. Once you write some, this is where the recap lives.")
            .font(MiraTypography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.top, 16)
    }

    private var countersRow: some View {
        HStack(alignment: .top, spacing: 10) {
            counterCard(
                title: "Entries",
                value: "\(report.totalEntries)"
            )
            counterCard(
                title: "Words",
                value: "\(report.totalWords)"
            )
            counterCard(
                title: "Avg mood",
                value: report.averageMood.map { String(format: "%.1f", $0) } ?? "—"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func counterCard(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrowStyle()
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(MiraPalette.primaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var moodDistributionCard: some View {
        let counters = report.moodCounters
        let total = max(1, counters.total)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Mood distribution").eyebrowStyle()
            distributionRow(label: "Good", count: counters.good, total: total, level: 5)
            distributionRow(label: "Steady", count: counters.steady, total: total, level: 3)
            distributionRow(label: "Low", count: counters.low, total: total, level: 1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func distributionRow(label: LocalizedStringKey, count: Int, total: Int, level: Int) -> some View {
        let fraction = Double(count) / Double(total)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(size: 14, weight: .medium))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MiraPalette.primaryText.opacity(0.06))
                    Capsule()
                        .fill(MiraPalette.mood(level: level))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }

    private func bestMonthCard(_ best: StatisticsCalculator.YearReport.MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Best month").eyebrowStyle()
            Text(monthName(best.month))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            Text(String(
                format: String(localized: "Avg mood %.1f across %lld entries"),
                best.averageMood,
                best.entryCount
            ))
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var topTagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top tags").eyebrowStyle()
            FlowLayout(spacing: 8) {
                ForEach(report.topTags) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag.tag)")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(tag.count)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(MiraPalette.mood(level: 3).opacity(0.18)))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Longest streak").eyebrowStyle()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(report.longestStreak)")
                    .font(.system(size: 32, weight: .semibold, design: .serif).monospacedDigit())
                    .foregroundStyle(MiraPalette.primaryText)
                Text("days").font(MiraTypography.body).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func monthName(_ month: Int) -> String {
        var components = DateComponents()
        components.month = month
        components.year = report.year
        components.day = 1
        let date = Calendar.current.date(from: components) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
}

/// Tiny FlowLayout for tag pills — wraps to next line when out of
/// horizontal space. Inline here so YearInReview stays self-contained;
/// the rest of the app doesn't need a flow yet.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let width = proposal.width else { return .zero }
        let arranged = arrange(subviews: subviews, in: width)
        return CGSize(width: width, height: arranged.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arranged = arrange(subviews: subviews, in: bounds.width)
        for placement in arranged.placements {
            let origin = CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y)
            placement.subview.place(
                at: origin,
                proposal: ProposedViewSize(width: placement.size.width, height: placement.size.height)
            )
        }
    }

    private struct Placement {
        let subview: LayoutSubview
        let x: CGFloat
        let y: CGFloat
        let size: CGSize
    }

    private struct Arranged {
        let placements: [Placement]
        let height: CGFloat
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> Arranged {
        var placements: [Placement] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            placements.append(Placement(subview: subview, x: x, y: y, size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return Arranged(placements: placements, height: y + rowHeight)
    }
}
