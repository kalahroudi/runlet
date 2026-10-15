import AppKit
import SwiftUI

/// The menu bar icon and the popover anchored to it with an arrow.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    static let shared = StatusBarController()

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    func install() {
        if let button = item.button {
            let image = NSImage(systemSymbolName: "chevron.right.square", accessibilityDescription: "RunLet")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(toggle)
        }
        let host = NSHostingController(rootView: PopoverView())
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient   // closes on a click outside and on Esc
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    @objc private func toggle() {
        popover.isShown ? close() : open()
    }

    func open() {
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Bring the app forward so typing goes straight into the popover.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        UpdateModel.shared.checkIfStale()
    }

    func close() {
        popover.performClose(nil)
    }
}
