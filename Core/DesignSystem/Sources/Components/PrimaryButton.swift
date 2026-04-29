import SwiftUI

public struct PrimaryButton: View {
    private let title: String
    private let isLoading: Bool
    private let action: () -> Void

    public init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().controlSize(.small) }
                Text(title).font(MiraTypography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
}
