import SwiftUI
import UIKit
import CoreKit

// MARK: - Controller

/// Shared controller the dock + the SwiftUI view talk to. Owns a weak
/// reference to the live `UITextView` and exposes style + list mutations
/// that operate on the current selection (or `typingAttributes` when the
/// selection is empty). State containers read `currentStyle` /
/// `currentLineToken` for dock highlighting.
@MainActor
@Observable
public final class MiraRichTextController {
    public private(set) var currentStyle: EntrySelectionStyle = EntrySelectionStyle()
    public private(set) var currentLineToken: EntryLineToken? = nil
    public private(set) var hasRangeSelection: Bool = false

    /// Set by the representable when the UITextView is created. The host
    /// holds the controller in `@State`, so this stays alive across updates.
    fileprivate weak var textView: UITextView?

    /// Toggled by the representable so callbacks emitted by UIKit during a
    /// programmatic edit don't bounce back through the binding.
    fileprivate var isApplyingProgrammaticEdit = false

    public init() {}

    // MARK: - Style queries

    public func refreshFromTextView() {
        guard let tv = textView else { return }
        let resolved = resolvedStyle(in: tv)
        if resolved != currentStyle { currentStyle = resolved }
        let token = computeLineToken(in: tv)
        if token != currentLineToken { currentLineToken = token }
        let hasRange = tv.selectedRange.length > 0
        if hasRange != hasRangeSelection { hasRangeSelection = hasRange }
    }

    private func resolvedStyle(in tv: UITextView) -> EntrySelectionStyle {
        if tv.selectedRange.length == 0 {
            return styleFromAttributes(tv.typingAttributes)
        }
        return styleFromRunsInRange(tv.selectedRange, storage: tv.textStorage)
    }

    private func styleFromAttributes(_ attrs: [NSAttributedString.Key: Any]) -> EntrySelectionStyle {
        var style = EntrySelectionStyle()
        if let raw = attrs[RichTextAttributeBridge.familyKey] as? String {
            style.family = EntryFontFamily(rawValue: raw)
        }
        if let raw = attrs[RichTextAttributeBridge.sizeKey] as? Int {
            style.size = EntryFontSize(rawValue: raw)
        }
        if let raw = attrs[RichTextAttributeBridge.colorKey] as? String {
            style.color = EntryTextColor(storageString: raw)
        }
        if let font = attrs[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            style.bold = traits.contains(.traitBold)
            style.italic = traits.contains(.traitItalic)
        }
        if let raw = attrs[.underlineStyle] as? Int {
            style.underline = raw != 0
        } else {
            style.underline = false
        }
        return style
    }

    /// Reduces over the runs intersecting `range` and returns the uniform
    /// style. Any facet that varies inside the range comes back nil so the
    /// dock shows "Mixed".
    private func styleFromRunsInRange(_ range: NSRange, storage: NSTextStorage) -> EntrySelectionStyle {
        var family: EntryFontFamily??
        var size: EntryFontSize??
        var color: EntryTextColor??
        var bold: Bool??
        var italic: Bool??
        var underline: Bool??

        func reduce<T: Equatable>(_ acc: inout T??, _ next: T?) {
            switch acc {
            case .none: acc = .some(next)
            case .some(let existing): if existing != next { acc = .some(nil) }
            }
        }

        storage.enumerateAttributes(in: range) { attrs, _, _ in
            let s = self.styleFromAttributes(attrs)
            reduce(&family, s.family)
            reduce(&size, s.size)
            reduce(&color, s.color)
            reduce(&bold, s.bold)
            reduce(&italic, s.italic)
            reduce(&underline, s.underline)
        }

        return EntrySelectionStyle(
            family: family ?? nil,
            size: size ?? nil,
            color: color ?? nil,
            bold: bold ?? nil,
            italic: italic ?? nil,
            underline: underline ?? nil
        )
    }

    private func computeLineToken(in tv: UITextView) -> EntryLineToken? {
        let attributed = RichTextAttributeBridge.attributedString(from: tv.attributedText)
        let cursor = tv.selectedRange.location
        let chars = attributed.characters
        guard cursor >= 0 && cursor <= chars.count else { return nil }
        return EntryContentEditor.lineInfo(in: attributed, at: cursor)?.token
    }

    // MARK: - Style mutations

    public func toggleBold() { toggleTrait(.traitBold) }
    public func toggleItalic() { toggleTrait(.traitItalic) }

    public func toggleUnderline() {
        guard let tv = textView else { return }
        let on = (currentStyle.underline ?? false)
        mutateAttributes(in: tv) { attrs in
            attrs[.underlineStyle] = on ? nil : NSUnderlineStyle.single.rawValue
        }
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let on = trait == .traitBold ? (currentStyle.bold ?? false)
                                     : (currentStyle.italic ?? false)
        mutateAttributes(in: tv) { attrs in
            guard let font = attrs[.font] as? UIFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            if on { traits.remove(trait) } else { traits.insert(trait) }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                ?? font.fontDescriptor
            attrs[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
        }
    }

    public func applyFontFamily(_ family: EntryFontFamily) {
        guard let tv = textView else { return }
        mutateAttributes(in: tv) { attrs in
            let size = (attrs[RichTextAttributeBridge.sizeKey] as? Int)
                .flatMap(EntryFontSize.init(rawValue:)) ?? .regular
            let bold = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
            let italic = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
            attrs[.font] = RichTextAttributeBridge.uiFont(
                family: family, size: size, bold: bold, italic: italic
            )
            attrs[RichTextAttributeBridge.familyKey] = family.rawValue
        }
    }

    public func applyFontSize(_ size: EntryFontSize) {
        guard let tv = textView else { return }
        mutateAttributes(in: tv) { attrs in
            let family = (attrs[RichTextAttributeBridge.familyKey] as? String)
                .flatMap(EntryFontFamily.init(rawValue:)) ?? .serif
            let bold = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
            let italic = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
            attrs[.font] = RichTextAttributeBridge.uiFont(
                family: family, size: size, bold: bold, italic: italic
            )
            attrs[RichTextAttributeBridge.sizeKey] = size.rawValue
        }
    }

    public func applyTextColor(_ color: EntryTextColor) {
        guard let tv = textView else { return }
        mutateAttributes(in: tv) { attrs in
            attrs[.foregroundColor] = RichTextAttributeBridge.uiColor(for: color)
            attrs[RichTextAttributeBridge.colorKey] = color.storageString
        }
    }

    /// Single mutation path — applies `body` to the relevant attribute dict.
    /// For a range selection, we walk every run inside the range so the
    /// change is uniform. For an insertion point, we mutate `typingAttributes`
    /// only — UITextView carries those over to the next typed character.
    private func mutateAttributes(
        in tv: UITextView,
        _ body: (inout [NSAttributedString.Key: Any]) -> Void
    ) {
        isApplyingProgrammaticEdit = true
        defer { isApplyingProgrammaticEdit = false }

        if tv.selectedRange.length > 0 {
            let storage = tv.textStorage
            let editRange = tv.selectedRange
            storage.beginEditing()
            storage.enumerateAttributes(in: editRange) { runAttrs, runRange, _ in
                var mut = runAttrs
                body(&mut)
                storage.setAttributes(mut, range: runRange)
            }
            storage.endEditing()
            // Keep typing attributes consistent so further typing inherits
            // the edited style.
            var typing = tv.typingAttributes
            body(&typing)
            tv.typingAttributes = typing
            tv.selectedRange = editRange
        } else {
            var typing = tv.typingAttributes
            body(&typing)
            tv.typingAttributes = typing
        }
        refreshFromTextView()
        tv.delegate?.textViewDidChange?(tv)
    }

    // MARK: - List actions

    public func applyListAction(_ action: EntryContentEditor.ListAction) {
        guard let tv = textView else { return }
        let current = RichTextAttributeBridge.attributedString(from: tv.attributedText)
        let cursor = tv.selectedRange.location
        guard let result = EntryContentEditor.applyListAction(action, in: current, at: cursor) else {
            return
        }
        isApplyingProgrammaticEdit = true
        defer { isApplyingProgrammaticEdit = false }
        let ns = RichTextAttributeBridge.nsAttributedString(from: result.content)
        tv.attributedText = ns
        let location = min(result.cursorCharOffset, ns.length)
        tv.selectedRange = NSRange(location: location, length: 0)
        refreshFromTextView()
        tv.delegate?.textViewDidChange?(tv)
    }
}

// MARK: - Representable

/// SwiftUI wrapper around `UITextView` configured for rich-text journal
/// editing. Bridges to `MiraRichTextController` for style/list mutations
/// the dock fires, and writes back content + selection updates via
/// callbacks. Designed to live inside a SwiftUI `ScrollView` — the inner
/// text view has scrolling disabled and reports its intrinsic size so the
/// outer scroll handles paging.
public struct MiraRichTextEditor: UIViewRepresentable {
    @Binding var content: AttributedString
    let controller: MiraRichTextController
    let isEditable: Bool
    let placeholder: String
    let onCommitContent: (AttributedString) -> Void
    let onFocusChange: (Bool) -> Void

    public init(
        content: Binding<AttributedString>,
        controller: MiraRichTextController,
        isEditable: Bool = true,
        placeholder: String = "",
        onCommitContent: @escaping (AttributedString) -> Void = { _ in },
        onFocusChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self._content = content
        self.controller = controller
        self.isEditable = isEditable
        self.placeholder = placeholder
        self.onCommitContent = onCommitContent
        self.onFocusChange = onFocusChange
    }

    public func makeUIView(context: Context) -> ScrollFreeTextView {
        let tv = ScrollFreeTextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.isEditable = isEditable
        tv.allowsEditingTextAttributes = true
        tv.backgroundColor = .clear
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        tv.adjustsFontForContentSizeCategory = false
        tv.dataDetectorTypes = []

        let initialAttrs = RichTextAttributeBridge.defaultAttributes()
        tv.typingAttributes = initialAttrs
        tv.attributedText = RichTextAttributeBridge.nsAttributedString(from: content)

        controller.textView = tv
        context.coordinator.textView = tv
        DispatchQueue.main.async {
            controller.refreshFromTextView()
        }
        return tv
    }

    public func updateUIView(_ tv: ScrollFreeTextView, context: Context) {
        if tv.isEditable != isEditable { tv.isEditable = isEditable }
        // Only rewrite storage when the binding diverges from what we last
        // emitted — otherwise every keystroke would round-trip through the
        // binding and reset the cursor.
        if context.coordinator.lastEmittedContent != content {
            context.coordinator.lastEmittedContent = content
            let ns = RichTextAttributeBridge.nsAttributedString(from: content)
            let cursor = tv.selectedRange
            tv.attributedText = ns
            let safeLocation = min(cursor.location, ns.length)
            let safeLength = min(cursor.length, ns.length - safeLocation)
            tv.selectedRange = NSRange(location: safeLocation, length: safeLength)
            tv.invalidateIntrinsicContentSize()
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MiraRichTextEditor
        weak var textView: UITextView?
        var lastEmittedContent: AttributedString?

        init(parent: MiraRichTextEditor) {
            self.parent = parent
        }

        public func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Enter-continuation: when the user presses Return on a list
            // line, mirror the marker on the next line (or strip it if the
            // marker had no body — exits list mode).
            guard text == "\n" else { return true }
            let oldNS = textView.attributedText ?? NSAttributedString()
            let mutable = NSMutableAttributedString(attributedString: oldNS)
            mutable.replaceCharacters(in: range, with: "\n")
            let newAttributed = RichTextAttributeBridge.attributedString(from: mutable)
            let cursorAfterNewline = range.location + 1
            guard let result = EntryContentEditor.handleEnterContinuation(
                oldContent: RichTextAttributeBridge.attributedString(from: oldNS),
                newContent: newAttributed,
                cursorCharOffset: cursorAfterNewline
            ) else {
                return true
            }
            parent.controller.isApplyingProgrammaticEdit = true
            defer { parent.controller.isApplyingProgrammaticEdit = false }
            let ns = RichTextAttributeBridge.nsAttributedString(from: result.content)
            textView.attributedText = ns
            let location = min(result.cursorCharOffset, ns.length)
            textView.selectedRange = NSRange(location: location, length: 0)
            textViewDidChange(textView)
            return false
        }

        public func textViewDidChange(_ textView: UITextView) {
            let attributed = RichTextAttributeBridge.attributedString(from: textView.attributedText)
            lastEmittedContent = attributed
            parent.content = attributed
            parent.onCommitContent(attributed)
            parent.controller.refreshFromTextView()
            (textView as? ScrollFreeTextView)?.invalidateIntrinsicContentSize()
        }

        public func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller.refreshFromTextView()
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange(true)
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange(false)
        }
    }
}

// MARK: - Scroll-free UITextView

/// `UITextView` subclass whose intrinsic content size hugs its text — so it
/// can live inside an outer `ScrollView` without competing with it for the
/// pan gesture and without collapsing to zero height.
public final class ScrollFreeTextView: UITextView {
    public override var intrinsicContentSize: CGSize {
        guard bounds.width > 0 else { return CGSize(width: UIView.noIntrinsicMetric, height: 240) }
        let target = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        let fitted = sizeThatFits(target)
        return CGSize(width: UIView.noIntrinsicMetric, height: max(fitted.height, 240))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
