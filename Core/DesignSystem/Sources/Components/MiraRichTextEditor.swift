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

    /// Source of truth for the attributes the *next* typed character should
    /// inherit. UITextView's `typingAttributes` silently drops our custom
    /// shadow keys (familyKey/sizeKey/colorKey) right after every insertion,
    /// so relying on it gives only the first character the picked style. We
    /// keep our own copy and use it directly in `shouldChangeTextIn` to
    /// stamp every inserted character with the full set.
    fileprivate var stickyTypingAttributes: [NSAttributedString.Key: Any] =
        RichTextAttributeBridge.defaultAttributes()

    public init() {}

    // MARK: - Focus

    @discardableResult
    public func focus() -> Bool {
        textView?.becomeFirstResponder() ?? false
    }

    @discardableResult
    public func resignFocus() -> Bool {
        textView?.resignFirstResponder() ?? false
    }

    public var isFocused: Bool {
        textView?.isFirstResponder ?? false
    }

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
            // Read from sticky, not tv.typingAttributes — UIKit strips our
            // custom shadow keys after each insertion, so typingAttributes
            // would make the dock highlight blink off after every keystroke.
            return styleFromAttributes(stickyTypingAttributes)
        }
        return styleFromRunsInRange(tv.selectedRange, storage: tv.textStorage)
    }

    /// Reads the storage attrs at the character preceding the cursor and
    /// stores them as `stickyTypingAttributes`. Used after a real cursor
    /// move (no edit) so the dock highlight + the next typed character
    /// reflect the surrounding style.
    fileprivate func syncStickyFromCursor() {
        guard let tv = textView else { return }
        let storage = tv.textStorage
        guard storage.length > 0 else {
            stickyTypingAttributes = RichTextAttributeBridge.defaultAttributes()
            return
        }
        let cursor = tv.selectedRange.location
        let pos = max(0, min(cursor - 1, storage.length - 1))
        stickyTypingAttributes = storage.attributes(at: pos, effectiveRange: nil)
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
    /// change is uniform. For an insertion point, we mutate
    /// `stickyTypingAttributes` (and mirror to `typingAttributes` for the
    /// system Format menu's sake), and `shouldChangeTextIn` will stamp the
    /// next typed character with the full set.
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
            // Keep sticky + typingAttributes consistent so further typing
            // inherits the edited style. We build from sticky (not
            // tv.typingAttributes) because UIKit strips our shadow keys.
            var typing = stickyTypingAttributes
            body(&typing)
            stickyTypingAttributes = typing
            tv.typingAttributes = typing
            tv.selectedRange = editRange
        } else {
            var typing = stickyTypingAttributes
            body(&typing)
            stickyTypingAttributes = typing
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
        syncStickyFromCursor()
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
        // The custom dock (font/size/color/B/I/U + lists) owns all styling.
        // Disable the system Format edit-menu so users don't get a parallel
        // path that bypasses our sticky typing attributes.
        tv.allowsEditingTextAttributes = false
        tv.backgroundColor = .clear
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        tv.adjustsFontForContentSizeCategory = false
        tv.dataDetectorTypes = []

        let initialAttrs = RichTextAttributeBridge.defaultAttributes()
        tv.typingAttributes = initialAttrs
        tv.attributedText = RichTextAttributeBridge.nsAttributedString(from: content)

        controller.textView = tv
        controller.stickyTypingAttributes = initialAttrs
        context.coordinator.textView = tv
        DispatchQueue.main.async {
            controller.syncStickyFromCursor()
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
            // Storage was just replaced; refresh sticky from the (possibly
            // new) cursor position so the next typed character inherits
            // the surrounding style rather than stale defaults.
            controller.syncStickyFromCursor()
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
            // Empty replacement text is a deletion — let UIKit handle it.
            if text.isEmpty { return true }

            // Enter-continuation: when the user presses Return on a list
            // line, mirror the marker on the next line (or strip it if the
            // marker had no body — exits list mode).
            if text == "\n" {
                let oldNS = textView.attributedText ?? NSAttributedString()
                let mutable = NSMutableAttributedString(attributedString: oldNS)
                mutable.replaceCharacters(in: range, with: "\n")
                let newAttributed = RichTextAttributeBridge.attributedString(from: mutable)
                let cursorAfterNewline = range.location + 1
                if let result = EntryContentEditor.handleEnterContinuation(
                    oldContent: RichTextAttributeBridge.attributedString(from: oldNS),
                    newContent: newAttributed,
                    cursorCharOffset: cursorAfterNewline
                ) {
                    parent.controller.isApplyingProgrammaticEdit = true
                    defer { parent.controller.isApplyingProgrammaticEdit = false }
                    let ns = RichTextAttributeBridge.nsAttributedString(from: result.content)
                    textView.attributedText = ns
                    let location = min(result.cursorCharOffset, ns.length)
                    textView.selectedRange = NSRange(location: location, length: 0)
                    textViewDidChange(textView)
                    return false
                }
                // Fall through: regular (non-list) "\n" stamped with sticky.
            }

            // Stamp the inserted text with the controller's sticky attrs.
            // We bypass UIKit's `typingAttributes` because UIKit drops our
            // custom shadow keys (familyKey/sizeKey/colorKey) from it after
            // every insertion, so only the first typed character would
            // otherwise carry the picked style.
            let attrs = parent.controller.stickyTypingAttributes
            let storage = textView.textStorage
            parent.controller.isApplyingProgrammaticEdit = true
            defer { parent.controller.isApplyingProgrammaticEdit = false }
            storage.beginEditing()
            storage.replaceCharacters(
                in: range,
                with: NSAttributedString(string: text, attributes: attrs)
            )
            storage.endEditing()
            let newCursor = range.location + (text as NSString).length
            textView.selectedRange = NSRange(location: newCursor, length: 0)
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
            // Resync sticky from the storage at the new cursor so the dock
            // highlight + the next typed character match the surrounding
            // style. We read directly from storage (which keeps our shadow
            // keys) rather than from `tv.typingAttributes` (which UIKit
            // strips them from). The `isApplyingProgrammaticEdit` guard
            // skips selection callbacks fired during our own storage edits
            // — those leave sticky as the user picked it, not as the
            // surrounding text.
            if !parent.controller.isApplyingProgrammaticEdit {
                parent.controller.syncStickyFromCursor()
            }
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
