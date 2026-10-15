/// Something the coordinator can bring to the front and ask whether it was closed.
public protocol ManagedWindow: AnyObject {
    var isClosed: Bool { get }
    func bringToFront()
}

/// Keeps at most one live window of a kind. Asking to show it again re-uses the open one.
public final class WindowCoordinator<Window: ManagedWindow> {
    private let make: () -> Window
    private var current: Window?

    public init(make: @escaping () -> Window) {
        self.make = make
    }

    public func show() {
        if let window = current, !window.isClosed {
            window.bringToFront()
        } else {
            let window = make()
            current = window
            window.bringToFront()
        }
    }
}
