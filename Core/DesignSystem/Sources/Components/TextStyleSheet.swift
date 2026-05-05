import SwiftUI
import UIKit
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
    @State private var showSystemColorPicker: Bool = false

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
        Button {
            if !isPro {
                paywallPresenter.present(.feature(.themesAndIcons))
                return
            }
            showSystemColorPicker = true
        } label: {
            ZStack {
                // Rainbow gradient — visible target.
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

                // Pro badge — top-right of the swatch, non-interactive so
                // taps go through to the Button.
                if !isPro {
                    ProBadge()
                        .scaleEffect(0.6)
                        .offset(x: 18, y: -18)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSystemColorPicker) {
            // Color picker hosted as a SwiftUI sheet so iOS doesn't try
            // to stack a UIKit modal on top of the parent TextStyleSheet
            // (that's the "Currently, only presenting a single sheet is
            // supported" path that left the previous attempt silent).
            // Picking a color updates the entry immediately; Done just
            // dismisses the sheet.
            ColorPickerSheet(
                initialColor: customColor,
                onChange: { newColor in
                    customColor = newColor
                    onTextColor(.custom(hex: newColor.toHexString()))
                },
                onDismiss: { showSystemColorPicker = false }
            )
            .ignoresSafeArea()
            .presentationDetents([.large])
        }
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

/// Wraps `UIColorPickerViewController` so it can be hosted as the
/// content of a SwiftUI `.sheet`. Presenting the system colour picker
/// this way avoids the "Currently, only presenting a single sheet is
/// supported" warning that fires when UIKit tries to stack a modal
/// on top of an active SwiftUI sheet.
private struct ColorPickerSheet: UIViewControllerRepresentable {
    let initialColor: Color
    var onChange: (Color) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(initialColor)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIColorPickerViewController, context: Context) {
        // Keep the coordinator's reference to the latest closures so the
        // delegate calls forward to the right state if the host view
        // re-renders mid-pick.
        context.coordinator.onChange = onChange
        context.coordinator.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var onChange: (Color) -> Void
        var onDismiss: () -> Void

        init(onChange: @escaping (Color) -> Void, onDismiss: @escaping () -> Void) {
            self.onChange = onChange
            self.onDismiss = onDismiss
        }

        func colorPickerViewControllerDidSelectColor(_ vc: UIColorPickerViewController) {
            onChange(Color(vc.selectedColor))
        }

        func colorPickerViewControllerDidFinish(_ vc: UIColorPickerViewController) {
            onDismiss()
        }
    }
}
