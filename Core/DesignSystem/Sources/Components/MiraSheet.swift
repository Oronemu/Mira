import SwiftUI

/// House sheet primitives — one place to evolve the modal chrome
/// (drag handle, headers, corner radius, presentation background) so
/// every sheet in the app reads the same regardless of what's inside.
///
/// Two consumption patterns:
/// - Bottom-style sheets (focused tasks, e.g. MoodPicker, Tags):
///   `MiraDragHandle` + `MiraSheetHeader` + `.miraSheet([.medium, .large])`.
/// - Modal-style sheets (navigation + form): wrap content in
///   `MiraSheetChrome` + `.miraSheet(...)` + hide the system Form/nav
///   chrome with `.scrollContentBackground(.hidden)` and
///   `.toolbarBackground(.hidden, for: .navigationBar)`.

// MARK: - Modifier

public extension View {
    /// Standard sheet chrome: clear presentation background so the
    /// content's own background paints through, soft 36pt corners,
    /// system drag indicator hidden (callers add `MiraDragHandle` if
    /// they want one). Pass a custom detent set for fixed heights.
    func miraSheet(_ detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationBackground(.clear)
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
    }
}

// MARK: - Drag handle

/// 42×5 capsule drawn at the top of every bottom-style sheet so the
/// user always has the same affordance for swipe-to-dismiss.
public struct MiraDragHandle: View {
    public init() {}

    public var body: some View {
        Capsule()
            .fill(MiraPalette.primaryText.opacity(0.14))
            .frame(width: 42, height: 5)
            .padding(.top, 10)
    }
}

// MARK: - Sheet header

/// Drag handle + title row + optional trailing action (typically a
/// "Done" button) used at the top of bottom-style sheets. Title uses
/// the displayTitle weight so headers feel weighted and editorial.
public struct MiraSheetHeader<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    @ViewBuilder private let trailing: () -> Trailing

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    public var body: some View {
        VStack(spacing: 0) {
            MiraDragHandle()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MiraTypography.displayTitle)
                        .foregroundStyle(MiraPalette.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(MiraPalette.secondaryText)
                    }
                }
                Spacer(minLength: 12)
                trailing()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Done button

/// Plain-text "Done" button styled the same as the close action in
/// the canonical editor sheets (MoodPicker / Tags / TextStyle).
public struct MiraSheetDoneButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    public init(_ title: LocalizedStringKey = "Done", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chrome

/// Wraps sheet content in the house ambient background. Used for
/// modal-style sheets (NavigationStack/Form-based) so the system
/// chrome (form rows, nav bar) reads transparent over the same
/// quiet AmbientBackground that the rest of the app uses.
public struct MiraSheetChrome<Content: View>: View {
    private let moodLevels: [Int]
    private let intensity: Double
    @ViewBuilder private let content: () -> Content

    public init(
        moodLevels: [Int] = [3],
        intensity: Double = 0.55,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.moodLevels = moodLevels
        self.intensity = intensity
        self.content = content
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: moodLevels, intensity: intensity)
            content()
        }
    }
}
