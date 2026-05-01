import SwiftUI

/// Editorial pill segmented control. A row of glass-tinted segments with
/// a soft tint-colored capsule riding behind the selected option. Picked
/// over `Picker(.segmented)` because the standard chrome fights the
/// serif / Liquid Glass aesthetic of the app.
///
/// Generic over any `Hashable` value so the same control fits a
/// `Range`-like enum (Stats screen) or a remote-provider list
/// (Intelligence settings). Pass `tint` to override the selection color
/// — defaults to the neutral mood-3 accent so the picker reads quietly
/// against any background.
public struct GlassPillPicker<Value: Hashable>: View {
    public let options: [Value]
    @Binding public var selection: Value
    public let tint: Color
    public let label: (Value) -> String

    @Namespace private var pillNamespace

    public init(
        options: [Value],
        selection: Binding<Value>,
        tint: Color = MiraPalette.mood(level: 3),
        label: @escaping (Value) -> String
    ) {
        self.options = options
        self._selection = selection
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .animation(.spring(duration: 0.35, bounce: 0.15), value: selection)
    }

    private func segment(for option: Value) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(label(option))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .serif))
                .foregroundStyle(isSelected ? MiraPalette.primaryText : MiraPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(tint.opacity(0.28))
                            .matchedGeometryEffect(id: "glass.pill.selection", in: pillNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
