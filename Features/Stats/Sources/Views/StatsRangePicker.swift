import SwiftUI
import Utilities
import DesignSystem

/// Editorial pill segmented control. Three glass-tinted segments (Week /
/// Month / Year) — selection rides on a soft mood-colored capsule. Picked
/// over `Picker(.segmented)` because the standard look fights the serif /
/// glass aesthetic of the rest of the screen.
struct StatsRangePicker: View {
    @Binding var selection: StatisticsCalculator.Range
    let moodLevel: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatisticsCalculator.Range.allCases, id: \.self) { option in
                segment(for: option)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .animation(.spring(duration: 0.35, bounce: 0.15), value: selection)
    }

    private func segment(for option: StatisticsCalculator.Range) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(label(for: option))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .serif))
                .foregroundStyle(isSelected ? MiraPalette.primaryText : MiraPalette.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(MiraPalette.mood(level: moodLevel).opacity(0.28))
                            .matchedGeometryEffect(id: "stats.range.pill", in: pillNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @Namespace private var pillNamespace

    private func label(for option: StatisticsCalculator.Range) -> String {
        switch option {
        case .week:  String(localized: "Week", comment: "Stats range picker — last 7 days")
        case .month: String(localized: "Month", comment: "Stats range picker — last 30 days")
        case .year:  String(localized: "Year", comment: "Stats range picker — last 365 days")
        }
    }
}
