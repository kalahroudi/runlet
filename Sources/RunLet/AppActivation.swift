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
        showInDock()
        // The switch from menu-bar-only to a regular app is not instant. Sending the action in the same
        // turn finds no window handler and nothing opens, leaving only a Dock icon.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
}
