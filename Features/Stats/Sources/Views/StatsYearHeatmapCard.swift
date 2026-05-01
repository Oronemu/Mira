import SwiftUI
import Utilities
import DesignSystem

/// Year-strip heatmap, GitHub-flavored but in the mood palette. 53 columns
/// × 7 rows, leftmost = oldest week, rightmost = current. Cells with a
/// mood get tinted in the matching mood color (opacity by entry count);
/// cells without a mood but with entries get a neutral fill so the
/// "I journaled but didn't tag a mood" days still show up.
struct StatsYearHeatmapCard: View {

    let cells: [Utilities.StatisticsCalculator.HeatmapCell]

    private static let columnsPerYear = 53
    private static let rowsPerWeek = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            grid
            legend
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your year", comment: "Stats — year heatmap title")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            Text(subtitleText)
                .eyebrowStyle()
        }
    }

    private var subtitleText: String {
        let active = cells.filter { $0.count > 0 }.count
        return String(
            localized: "\(active) days with an entry",
            comment: "Stats — year heatmap subtitle, count of days with at least one entry"
        )
    }

    // MARK: - Grid

    private var grid: some View {
        // Column-major: cells are sorted ascending by date in 7-day chunks.
        let columns = stride(from: 0, to: cells.count, by: Self.rowsPerWeek).map { start in
            Array(cells[start..<min(start + Self.rowsPerWeek, cells.count)])
        }

        return GeometryReader { proxy in
            let width = proxy.size.width
            let cellSpacing: CGFloat = 2
            let columnCount = max(1, columns.count)
            let cellSide = max(
                3,
                (width - cellSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
            )
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week) { cell in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(fill(for: cell))
                                .frame(width: cellSide, height: cellSide)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: heatmapHeight)
    }

    private var heatmapHeight: CGFloat {
        // Same math as the grid so the GeometryReader has a fixed slot.
        // Keep it conservative — works at 320pt parent width.
        let cellSide: CGFloat = 5.5
        let spacing: CGFloat = 2
        return cellSide * 7 + spacing * 6
    }

    private func fill(for cell: Utilities.StatisticsCalculator.HeatmapCell) -> Color {
        if let avg = cell.averageMood {
            let level = max(1, min(5, Int(round(avg))))
            let intensity = min(1.0, 0.32 + 0.16 * Double(min(cell.count, 4)))
            return MiraPalette.mood(level: level).opacity(intensity)
        }
        if cell.count > 0 {
            return MiraPalette.primaryText.opacity(0.18)
        }
        return MiraPalette.primaryText.opacity(0.05)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 6) {
            Text("less", comment: "Stats — heatmap legend, lower-end label")
                .font(.system(size: 10))
                .foregroundStyle(MiraPalette.secondaryText)
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(MiraPalette.mood(level: 3).opacity(0.18 + Double(i) * 0.16))
                    .frame(width: 9, height: 9)
            }
            Text("more", comment: "Stats — heatmap legend, upper-end label")
                .font(.system(size: 10))
                .foregroundStyle(MiraPalette.secondaryText)
            Spacer()
        }
        .padding(.top, 4)
    }
}
