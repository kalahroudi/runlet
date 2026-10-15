import SwiftUI

@main
struct RunLetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("RunLet", systemImage: "chevron.right.square") {
            PopoverView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only until a window is open. Info.plist sets the same for the bundled app.
        RLFont.load()
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in UpdateModel.shared.startAutoChecks() }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { _ in
            DispatchQueue.main.async { AppActivation.returnToMenuBarOnlyIfIdle() }
        }
    }
}
