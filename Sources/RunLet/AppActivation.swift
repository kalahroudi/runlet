import AppKit

/// The app lives in the menu bar and only shows a Dock icon while a real window is open.
enum AppActivation {
    static func showInDock() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func returnToMenuBarOnlyIfIdle() {
        let hasWindow = NSApp.windows.contains { window in
            window.isVisible && !(window is NSPanel) && window.level == .normal
        }
        if !hasWindow { NSApp.setActivationPolicy(.accessory) }
    }

    static func openSettings() {
        AppWindows.settings.show()
    }
}
