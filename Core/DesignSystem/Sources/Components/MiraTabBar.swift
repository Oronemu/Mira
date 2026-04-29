import SwiftUI

public struct MiraTabItem<Value: Hashable>: Identifiable {
    public let value: Value
    public let title: LocalizedStringResource
    public let systemImage: String

    public var id: Value { value }

    public init(value: Value, title: LocalizedStringResource, systemImage: String) {
        self.value = value
        self.title = title
        self.systemImage = systemImage
    }
}

/// Fully custom Liquid Glass tab bar. Floats above the bottom safe area, reveals
/// content behind the glass, and animates a mood-tinted pill under the active tab.
///
/// The bar does not participate in the system tab bar — visibility is driven by
/// the parent via `.hideTabBar()` + `TabBarVisibilityPreferenceKey`.
public struct MiraTabBar<Value: Hashable>: View {
    @Binding private var selection: Value
    private let items: [MiraTabItem<Value>]
    private let tint: Color

    @Namespace private var pillNamespace

    public init(
        selection: Binding<Value>,
        items: [MiraTabItem<Value>],
        tint: Color = .accentColor
    ) {
        self._selection = selection
        self.items = items
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .padding(.horizontal, 20)
    }

    private func tabButton(_ item: MiraTabItem<Value>) -> some View {
        let isSelected = selection == item.value
        return Button {
            guard selection != item.value else { return }
            selection = item.value
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolVariant(isSelected ? .fill : .none)
                    .symbolEffect(.bounce, value: isSelected)
                    .frame(height: 22)

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? tint : MiraPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Capsule(style: .continuous))
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.14))
                        .matchedGeometryEffect(id: "mira.tabbar.pill", in: pillNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selection)
    }
}

#Preview("MiraTabBar") {
    @Previewable @State var selection: Int = 0

    ZStack {
        MiraPalette.surface.ignoresSafeArea()
        VStack {
            Spacer()
            MiraTabBar(
                selection: $selection,
                items: [
                    .init(value: 0, title: "Journal", systemImage: "book"),
                    .init(value: 1, title: "Ask", systemImage: "sparkles"),
                    .init(value: 2, title: "Insights", systemImage: "quote.bubble"),
                    .init(value: 3, title: "Settings", systemImage: "gearshape"),
                ],
                tint: MiraPalette.mood(level: 4)
            )
            .padding(.bottom, 8)
        }
    }
}
