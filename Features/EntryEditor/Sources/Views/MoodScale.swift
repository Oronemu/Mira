import SwiftUI
import CoreKit
import DesignSystem

/// Signature mood selector for the editor. Horizontal 1…5 scale with soft
/// mood-colored tiles; the selected tile picks up a sliding stroke via
/// `matchedGeometryEffect` and the currently selected label is echoed
/// underneath so the user always sees what they picked in words, not emoji.
public struct MoodScale: View {
    @Binding private var selection: Mood?
    @Namespace private var indicator

    public init(selection: Binding<Mood?>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    cell(for: mood)
                }
            }

            Text(selection?.label ?? String(localized: "Tap to set a mood"))
                .eyebrowStyle(
                    color: selection == nil
                        ? MiraPalette.secondaryText
                        : MiraPalette.primaryText.opacity(0.85)
                )
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.25), value: selection)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func cell(for mood: Mood) -> some View {
        let isSelected = mood == selection
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                selection = isSelected ? nil : mood
            }
        } label: {
            Text(mood.emoji)
                .font(.system(size: 28))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MiraPalette.moodSoft(level: mood.rawValue))
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                MiraPalette.primaryText.opacity(0.5),
                                lineWidth: 1.5
                            )
                            .matchedGeometryEffect(id: "indicator", in: indicator)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct PreviewHost: View {
        @State var selection: Mood? = .good
        var body: some View {
            ZStack {
                MiraPalette.surface.ignoresSafeArea()
                MoodScale(selection: $selection)
                    .padding(24)
            }
        }
    }
    return PreviewHost()
}
