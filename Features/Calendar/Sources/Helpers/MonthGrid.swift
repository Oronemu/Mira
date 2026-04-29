import Foundation

/// Layout helper: returns the days that should appear in a month grid,
/// padded with leading nils so the first column matches the locale's
/// first weekday.
public enum MonthGrid {
    public struct Cell: Hashable, Sendable {
        public let date: Date?
    }

    public static func cells(for month: Date, calendar: Calendar = .current) -> [Cell] {
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard
            let firstOfMonth = calendar.date(from: comps),
            let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Cell] = Array(repeating: Cell(date: nil), count: leadingBlanks)
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(Cell(date: d))
            }
        }
        // Pad to a full 6-row grid for stable layout (42 cells).
        while cells.count < 42 {
            cells.append(Cell(date: nil))
        }
        return cells
    }

    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}
