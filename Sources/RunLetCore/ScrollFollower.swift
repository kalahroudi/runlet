import Foundation

/// Where a scroll view is: how far it has scrolled, how tall its content is and how tall the visible part is.
public struct ScrollState: Equatable, Sendable {
    public var offset: Double
    public var content: Double
    public var viewport: Double

    /// Distances below this many points count as "at the edge", so rounding never shows a fade.
    public static let slack = 4.0

    public init(offset: Double, content: Double, viewport: Double) {
        self.offset = offset
        self.content = content
        self.viewport = viewport
    }

    public var hiddenAbove: Bool { offset > Self.slack }
    public var hiddenBelow: Bool { content - viewport - offset > Self.slack }
}

/// Decides whether a console follows new output (it is at the bottom) or stays where the person scrolled to.
public struct ScrollFollower: Equatable, Sendable {
    public private(set) var isFollowing = true
    private var lastContent = 0.0

    public init() {}

    /// Call whenever the scroll state changes. Returns true when the view should scroll to the end now.
    public mutating func update(_ state: ScrollState) -> Bool {
        let grew = state.content > lastContent + 0.5
        lastContent = state.content
        if grew && isFollowing { return true }
        isFollowing = !state.hiddenBelow
        return false
    }

    /// The "Jump to latest" button was pressed.
    public mutating func jumpToLatest() { isFollowing = true }

    /// True while the view is scrolled up and new output is not moving it.
    public var showsJumpButton: Bool { !isFollowing }
}
