import AppKit
import SwiftUI
import RunLetCore

final class MainWindow: NSObject, ManagedWindow, NSWindowDelegate {
    private let window: NSWindow
    private(set) var isClosed = false

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        super.init()
        window.title = "RunLet"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainWindowView())
        window.center()
        window.delegate = self
    }

    func bringToFront() {
        AppActivation.showInDock()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        isClosed = true
    }
}

enum AppWindows {
    static let main = WindowCoordinator<MainWindow> { MainWindow() }
}
