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

/// Settings in a window we own. The SwiftUI Settings scene cannot be opened reliably from a menu bar popover.
final class SettingsWindow: NSObject, ManagedWindow, NSWindowDelegate {
    private let window: NSWindow
    private(set) var isClosed = false

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        super.init()
        window.title = "RunLet Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
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
    static let settings = WindowCoordinator<SettingsWindow> { SettingsWindow() }
}
