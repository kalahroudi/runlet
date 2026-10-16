import AppKit

@main
enum RunLetMain {
    // The delegate must outlive `main`, because NSApplication only keeps a weak reference to it.
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only until a window is open. Info.plist sets the same for the bundled app.
        RLFont.load()
        MainMenu.install()
        Appearance.apply()
        NSApp.setActivationPolicy(.accessory)
        StatusBarController.shared.install()
        Task { @MainActor in UpdateModel.shared.startAutoChecks() }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { _ in
            DispatchQueue.main.async { AppActivation.returnToMenuBarOnlyIfIdle() }
        }
    }
}
