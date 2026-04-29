import SwiftUI
import CoreKit

/// Modal mood picker — 5 oversized bubbles with mood colour, emoji, and
/// label. Tapping commits and dismisses; there's also a Clear affordance
/// for entries where no mood fits.
public struct MoodPickerSheet: View {
    @Binding private var selection: Mood?
    @Environment(\.dismiss) private var dismiss

    public init(selection: Binding<Mood?>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Text("How are you feeling?")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
                .padding(.top, 18)
                .padding(.bottom, 4)

            Text("Tap a mood — you can clear it anytime.")
                .font(.system(size: 13))
                .foregroundStyle(MiraPalette.secondaryText)
                .padding(.bottom, 28)

            HStack(spacing: 10) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    bubble(for: mood)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)

            Button {
                selection = nil
                dismiss()
            } label: {
                Text("Clear mood")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Capsule())
            .padding(.bottom, 24)
            .opacity(selection == nil ? 0 : 1)
            .animation(.smooth(duration: 0.2), value: selection)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .presentationCornerRadius(36)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(MiraPalette.primaryText.opacity(0.14))
            .frame(width: 42, height: 5)
            .padding(.top, 10)
    }

    private func bubble(for mood: Mood) -> some View {
        let isSelected = selection == mood
        let color = MiraPalette.mood(level: mood.rawValue)
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                selection = isSelected ? nil : mood
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.85))
                    Circle()
                        .stroke(
                            isSelected
                                ? MiraPalette.primaryText.opacity(0.55)
                                : Color.clear,
                            lineWidth: 2
                        )
                    Text(mood.emoji)
                        .font(.system(size: 30))
                }
                .frame(width: 56, height: 56)
                .shadow(
                    color: color.opacity(isSelected ? 0.55 : 0),
                    radius: isSelected ? 14 : 0,
                    y: 4
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)

                Text(mood.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? MiraPalette.primaryText
                            : MiraPalette.secondaryText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("MoodPickerSheet") {
    struct Host: View {
        @State var mood: Mood? = .good
        @State var shown = true
        var body: some View {
            Color.clear.sheet(isPresented: $shown) {
                MoodPickerSheet(selection: $mood)
            }
        }
    }
    return Host()
}
