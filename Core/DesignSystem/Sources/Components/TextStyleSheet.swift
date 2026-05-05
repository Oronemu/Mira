import SwiftUI
import CoreKit

/// Bottom sheet that edits the formatting of the current selection. Unlike
/// a binding-driven picker, this sheet is callback-driven because style is
/// stored on AttributedString ranges — the state container owns the
/// application logic and just tells us what the current selection looks
/// like via `current`.
///
/// When fields in `current` are nil, it means the selection spans runs with
/// different values for that facet; the sheet shows a neutral "mixed" state
/// for that control.
public struct TextStyleSheet: View {
    public let current: EntrySelectionStyle
    public let onFontFamily: (EntryFontFamily) -> Void
    public let onFontSize: (EntryFontSize) -> Void
    public let onTextColor: (EntryTextColor) -> Void
    public let onToggleBold: () -> Void
    public let onToggleItalic: () -> Void
    public let onToggleUnderline: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @State private var customColor: Color = .black
    @State private var isPro: Bool = false

    public init(
        current: EntrySelectionStyle,
        onFontFamily: @escaping (EntryFontFamily) -> Void,
        onFontSize: @escaping (EntryFontSize) -> Void,
        onTextColor: @escaping (EntryTextColor) -> Void,
        onToggleBold: @escaping () -> Void,
        onToggleItalic: @escaping () -> Void,
        onToggleUnderline: @escaping () -> Void
    ) {
        self.current = current
        self.onFontFamily = onFontFamily
        self.onFontSize = onFontSize
        self.onTextColor = onTextColor
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleUnderline = onToggleUnderline
    }

    public var body: some View {
        VStack(spacing: 0) {
            MiraSheetHeader("Text style") {
                MiraSheetDoneButton { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    emphasisRow
                    fontSection
                    sizeSection
                    colorSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .miraSheet([.medium, .large])
        .onAppear(perform: loadCustomColor)
        .task {
            isPro = (await subscriptionService.status).isPro
            for await snapshot in subscriptionService.statusUpdates {
                isPro = snapshot.isPro
            }
        }
    }

    // MARK: - Emphasis (B / I / U)

    private var emphasisRow: some View {
        HStack(spacing: 10) {
            emphasisButton(
                label: "B",
                weight: .bold,
                active: current.bold == true,
                action: onToggleBold
            )
            emphasisButton(
                label: "I",
                weight: .regular,
                italic: true,
                active: current.italic == true,
                action: onToggleItalic
            )
            emphasisButton(
                label: "U",
                weight: .regular,
                underline: true,
                active: current.underline == true,
                action: onToggleUnderline
            )
        }
    }

    private func emphasisButton(
        label: String,
        weight: Font.Weight,
        italic: Bool = false,
        underline: Bool = false,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        var text = Text(label)
            .font(.system(size: 17, weight: weight, design: .serif))
        if italic { text = text.italic() }
        if underline { text = text.underline() }
        return Button(action: action) {
            text
                .foregroundStyle(active ? Color.white : MiraPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? MiraPalette.accent : MiraPalette.secondaryBackground)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Font")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryFontFamily.allCases, id: \.rawValue) { family in
                        fontChip(family)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func fontChip(_ family: EntryFontFamily) -> some View {
        let isSelected = current.family == family
        return Button {
            onFontFamily(family)
        } label: {
            Text(family.label)
                .font(resolvedPreviewFont(family: family, size: .regular))
                .foregroundStyle(isSelected ? Color.white : MiraPalette.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? MiraPalette.accent : MiraPalette.secondaryBackground)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelected)
    }

    // MARK: - Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Size")
            HStack(spacing: 8) {
                ForEach(EntryFontSize.allCases, id: \.rawValue) { size in
                    sizeChip(size)
                }
            }
        }
    }

    private func sizeChip(_ size: EntryFontSize) -> some View {
        let isSelected = current.size == size
        return Button {
            onFontSize(size)
        } label: {
            Text(sizeGlyph(size))
                .font(.system(size: sizeGlyphPoint(size), weight: .semibold, design: .serif))
                .foregroundStyle(isSelected ? Color.white : MiraPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? MiraPalette.accent : MiraPalette.secondaryBackground)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelected)
    }

    private func sizeGlyph(_ size: EntryFontSize) -> String {
        switch size {
        case .small: "S"
        case .regular: "M"
        case .large: "L"
        case .extraLarge: "XL"
        }
    }

    private func sizeGlyphPoint(_ size: EntryFontSize) -> CGFloat {
        switch size {
        case .small: 14
        case .regular: 16
        case .large: 18
        case .extraLarge: 20
        }
    }

    // MARK: - Colour

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Colour")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EntryTextColor.Preset.allCases, id: \.rawValue) { preset in
                        presetSwatch(preset)
                    }
                    customSwatch
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func presetSwatch(_ preset: EntryTextColor.Preset) -> some View {
        let isSelected = isPresetSelected(preset)
        return Button {
            onTextColor(.preset(preset))
        } label: {
            ZStack {
                Circle()
                    .fill(MiraPalette.textColorSwatch(preset))
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .stroke(MiraPalette.accent, lineWidth: 2.5)
                        .frame(width: 44, height: 44)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.label)
    }

    private var customSwatch: some View {
        ZStack {
            // Rainbow gradient — purely decorative.
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
                        ]),
                        center: .center
                    )
                )
                .frame(width: 36, height: 36)
            if case .custom = current.color ?? .preset(.default) {
                Circle()
                    .stroke(MiraPalette.accent, lineWidth: 2.5)
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(customColor)
                    .frame(width: 22, height: 22)
            }

            // Hit handling. Free users get a Button that raises the paywall;
            // Pro users get the system ColorPicker. The ColorPicker is
            // scaled up so its (intrinsically small) tap target covers the
            // full 44pt swatch — without scaleEffect the hit area was a
            // sliver in the middle, which is what the user saw as "not
            // clickable".
            if isPro {
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { customColor },
                        set: { newColor in
                            customColor = newColor
                            onTextColor(.custom(hex: newColor.toHexString()))
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .scaleEffect(2.0)
                .opacity(0.02)
            } else {
                Button {
                    paywallPresenter.present(.feature(.themesAndIcons))
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Pro badge — top-right of the swatch, non-interactive so it
            // doesn't intercept taps meant for the picker / button.
            if !isPro {
                ProBadge()
                    .scaleEffect(0.6)
                    .offset(x: 18, y: -18)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Custom colour")
    }

    private func isPresetSelected(_ preset: EntryTextColor.Preset) -> Bool {
        if case .preset(let current) = current.color, current == preset {
            return true
        }
        return false
    }

    private func loadCustomColor() {
        if case .custom(let hex) = current.color ?? .preset(.default),
           let resolved = Color(hexString: hex) {
            customColor = resolved
        }
    }

    // MARK: - Bits

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(MiraPalette.secondaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func resolvedPreviewFont(family: EntryFontFamily, size: EntryFontSize) -> Font {
        let points = size.pointSize
        switch family {
        case .serif:       return .system(size: points, weight: .regular, design: .serif)
        case .sans:        return .system(size: points, weight: .regular, design: .default)
        case .rounded:     return .system(size: points, weight: .regular, design: .rounded)
        case .monospaced:  return .system(size: points, weight: .regular, design: .monospaced)
        case .georgia:     return .custom("Georgia", size: points)
        case .avenirNext:  return .custom("AvenirNext-Regular", size: points)
        }
    }
}

private extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    func toHexString() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rInt = Int((r * 255).rounded())
        let gInt = Int((g * 255).rounded())
        let bInt = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
}
