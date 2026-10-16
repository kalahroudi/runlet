import SwiftUI
import WebKit
import RunLetCore

/// The CodeMirror editor. `text` is the source of truth: edits in the editor update it, and setting it from
/// Swift replaces the editor's text without echoing a change back.
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    /// Called when the editor cannot load, so the caller can show a plain text box instead.
    var onFailure: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "runlet")
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = context.coordinator
        context.coordinator.web = web

        guard let folder = Bundle.main.resourceURL,
              FileManager.default.fileExists(atPath: folder.appendingPathComponent("editor/index.html").path) else {
            DispatchQueue.main.async { onFailure() }
            return web
        }
        // Read access to the whole Resources folder so the page can use the bundled font.
        web.loadFileURL(folder.appendingPathComponent("editor/index.html"), allowingReadAccessTo: folder)
        context.coordinator.startLoadTimer()
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.sync(text: text, dark: colorScheme == .dark)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: EditorView
        weak var web: WKWebView?
        private var ready = false
        private var failed = false
        private var current = ""
        private var themeSent: Bool?

        init(_ parent: EditorView) { self.parent = parent }

        func startLoadTimer() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, !self.ready else { return }
                self.fail()
            }
        }

        func sync(text: String, dark: Bool) {
            guard ready, let web else { return }
            if themeSent != dark {
                themeSent = dark
                web.evaluateJavaScript("RunLetEditor.setTheme(\(Self.themeJSON(dark: dark)))", completionHandler: nil)
            }
            if text != current {
                current = text
                web.evaluateJavaScript("RunLetEditor.setText(\(Self.literal(text)))", completionHandler: nil)
            }
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                ready = true
                themeSent = nil
                current = ""
                sync(text: parent.text, dark: parent.colorScheme == .dark)
                web?.evaluateJavaScript("RunLetEditor.focus()", completionHandler: nil)
            case "change":
                if let text = body["text"] as? String { current = text; parent.text = text }
            default: break
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail() }

        private func fail() {
            guard !failed else { return }
            failed = true
            parent.onFailure()
        }

        /// A JSON string literal, safe to place inside a script.
        private static func literal(_ text: String) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: [text])) ?? Data("[\"\"]".utf8)
            let array = String(decoding: data, as: UTF8.self)
            return String(array.dropFirst().dropLast())
        }

        private static func themeJSON(dark: Bool) -> String {
            func hex(_ token: Token) -> String {
                String(format: "#%06X", (dark ? token.dark : token.light).value)
            }
            let vars: [String: String] = [
                "bg": hex(Palette.codeBackground), "ink": hex(Palette.ink),
                "muted": hex(Palette.muted), "accent": hex(Palette.accent),
            ]
            let json = (try? JSONSerialization.data(withJSONObject: ["dark": dark, "vars": vars])) ?? Data("{}".utf8)
            return String(decoding: json, as: UTF8.self)
        }
    }
}
