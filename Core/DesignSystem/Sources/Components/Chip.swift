import SwiftUI

public struct Chip: View {
    private let label: String
    private let isSelected: Bool

    public init(_ label: String, isSelected: Bool = false) {
        self.label = label
        self.isSelected = isSelected
    }

    public var body: some View {
        Text(label)
            .font(MiraTypography.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? MiraPalette.accent.opacity(0.18) : MiraPalette.secondaryBackground)
            )
            .overlay(
                Capsule().stroke(isSelected ? MiraPalette.accent : MiraPalette.separator, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? MiraPalette.accent : MiraPalette.primaryText)
    }
}
