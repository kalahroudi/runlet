import SwiftUI
import AppKit
import RunLetCore

/// A plain text box whose paste goes through `CodeCleaner`. SwiftUI's `TextEditor` cannot intercept paste.
/// The original text goes in first and the cleaned text replaces it as a separate undo step.
struct PasteTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var onCleanedPaste: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        RLFont.load()
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        let view = CleaningTextView(frame: .zero)
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.font = NSFont(name: "JetBrains Mono", size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.textColor = .labelColor
        view.textContainerInset = NSSize(width: 0, height: 2)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.delegate = context.coordinator
        view.onCleanedPaste = { context.coordinator.parent.onCleanedPaste($0) }
        view.string = text
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PasteTextView
        init(_ parent: PasteTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, view.string != parent.text else { return }
            parent.text = view.string
        }
    }
}

final class CleaningTextView: NSTextView {
    var onCleanedPaste: ((String?) -> Void)?

    override func paste(_ sender: Any?) {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return super.paste(sender) }
        let result = CodeCleaner.clean(raw, mode: .paste)
        let range = selectedRange()
        insertText(raw, replacementRange: range)
        guard result.text != raw else { return }
        // Close the undo group so the cleaned text is its own step: one undo gives back the original paste.
        undoManager?.endUndoGrouping()
        undoManager?.beginUndoGrouping()
        insertText(result.text, replacementRange: NSRange(location: range.location, length: (raw as NSString).length))
        onCleanedPaste?(result.notice(for: .paste))
    }
}
