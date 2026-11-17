import AppKit
import SwiftUI

/// 原生单行密码/密钥输入视图（不触发 macOS 系统 AutoFill "Passwords..." 气泡，也不会粘滞在其他输入框上）
struct RadarSecureInputView: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isRevealed: Bool
    let monospaced: Bool
    let textColor: NSColor
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ClickableSecureScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = MaskedSingleLineTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isFieldEditor = true
        textView.usesFindBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .none
        }
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = true
        textView.minSize = NSSize(width: 200, height: 17)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isCopyBlockedProvider = { [weak coordinator = context.coordinator] in
            !(coordinator?.parent.isRevealed ?? true)
        }
        applyAppearance(to: textView)
        syncDisplayedText(on: textView, coordinator: context.coordinator, preserveCursor: false)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if let clickableScrollView = scrollView as? ClickableSecureScrollView {
            clickableScrollView.syncDocumentWidth()
        }
        guard let textView = context.coordinator.textView else { return }
        applyAppearance(to: textView)
        syncDisplayedText(on: textView, coordinator: context.coordinator, preserveCursor: true)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 220, height: 17)
    }

    private func applyAppearance(to textView: NSTextView) {
        let font =
            monospaced
            ? NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
            : NSFont.systemFont(ofSize: 12.5, weight: .regular)
        if textView.font != font {
            textView.font = font
        }
        textView.textColor = textColor
        textView.insertionPointColor = textColor
    }

    private func syncDisplayedText(on textView: NSTextView, coordinator: Coordinator, preserveCursor: Bool) {
        let desiredDisplay = isRevealed ? text : String(repeating: "•", count: (text as NSString).length)
        let revealedChanged = coordinator.lastRenderedRevealed != isRevealed
        let modelChanged = coordinator.lastSyncedModelText != text
        guard revealedChanged || modelChanged || textView.string != desiredDisplay else { return }

        let oldRange = textView.selectedRange()
        coordinator.isProgrammaticUpdate = true
        textView.string = desiredDisplay
        coordinator.lastSyncedModelText = text
        coordinator.lastRenderedRevealed = isRevealed
        if preserveCursor && textView.window?.firstResponder === textView {
            let maxLen = (desiredDisplay as NSString).length
            let loc = min(oldRange.location, maxLen)
            let len = min(oldRange.length, max(0, maxLen - loc))
            textView.setSelectedRange(NSRange(location: loc, length: len))
        }
        coordinator.isProgrammaticUpdate = false
    }

    @MainActor
    final class ClickableSecureScrollView: NSScrollView {
        func syncDocumentWidth() {
            guard let textView = documentView as? NSTextView else { return }
            let targetWidth = max(contentSize.width, 180)
            let targetHeight = max(contentSize.height, 17)
            if abs(textView.minSize.width - targetWidth) > 0.5 || abs(textView.minSize.height - targetHeight) > 0.5 {
                textView.minSize = NSSize(width: targetWidth, height: targetHeight)
            }
            if textView.frame.size.width < targetWidth || abs(textView.frame.size.height - targetHeight) > 0.5 {
                textView.frame.size = NSSize(width: max(textView.frame.size.width, targetWidth), height: targetHeight)
            }
        }

        override func layout() {
            super.layout()
            syncDocumentWidth()
        }

        override func mouseDown(with event: NSEvent) {
            if let textView = documentView as? NSTextView {
                window?.makeFirstResponder(textView)
                textView.mouseDown(with: event)
                return
            }
            super.mouseDown(with: event)
        }
    }

    @MainActor
    final class MaskedSingleLineTextView: NSTextView {
        var isCopyBlockedProvider: (@MainActor () -> Bool)?

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 17)
        }

        override func copy(_ sender: Any?) {
            if isCopyBlockedProvider?() == true {
                NSSound.beep()
                return
            }
            super.copy(sender)
        }

        override func cut(_ sender: Any?) {
            if isCopyBlockedProvider?() == true {
                NSSound.beep()
                return
            }
            super.cut(sender)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RadarSecureInputView
        weak var textView: NSTextView?
        var lastSyncedModelText = ""
        var lastRenderedRevealed = false
        var isProgrammaticUpdate = false

        init(_ parent: RadarSecureInputView) {
            self.parent = parent
            self.lastSyncedModelText = parent.text
            self.lastRenderedRevealed = parent.isRevealed
        }

        func textDidBeginEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = true
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = false
            }
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard !isProgrammaticUpdate, let replacementString else { return true }
            let cleanReplacement = replacementString.replacingOccurrences(of: "\n", with: "")
            if parent.isRevealed {
                if cleanReplacement != replacementString {
                    let nsCurrent = textView.string as NSString
                    let safeRange = clampedRange(affectedCharRange, length: nsCurrent.length)
                    let updated = nsCurrent.replacingCharacters(in: safeRange, with: cleanReplacement)
                    applyUpdatedText(
                        updated, cursorLocation: safeRange.location + (cleanReplacement as NSString).length)
                    return false
                }
                return true
            }

            let nsCurrent = parent.text as NSString
            let safeRange = clampedRange(affectedCharRange, length: nsCurrent.length)
            let updated = nsCurrent.replacingCharacters(in: safeRange, with: cleanReplacement)
            applyUpdatedText(updated, cursorLocation: safeRange.location + (cleanReplacement as NSString).length)
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, parent.isRevealed, let textView else { return }
            let current = textView.string
            if parent.text != current {
                lastSyncedModelText = current
                parent.text = current
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.window?.selectNextKeyView(textView)
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                textView.window?.selectPreviousKeyView(textView)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }

        private func clampedRange(_ range: NSRange, length: Int) -> NSRange {
            let loc = min(max(0, range.location), length)
            let len = min(max(0, range.length), max(0, length - loc))
            return NSRange(location: loc, length: len)
        }

        private func applyUpdatedText(_ updated: String, cursorLocation: Int) {
            guard let textView else { return }
            isProgrammaticUpdate = true
            lastSyncedModelText = updated
            parent.text = updated
            let rendered = parent.isRevealed ? updated : String(repeating: "•", count: (updated as NSString).length)
            textView.string = rendered
            let safeCursor = min(cursorLocation, (rendered as NSString).length)
            textView.setSelectedRange(NSRange(location: safeCursor, length: 0))
            isProgrammaticUpdate = false
        }
    }
}
