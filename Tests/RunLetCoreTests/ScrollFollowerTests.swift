import Testing
@testable import RunLetCore

@Suite struct ScrollFollowerTests {
    func state(_ offset: Double, content: Double, viewport: Double = 100) -> ScrollState {
        ScrollState(offset: offset, content: content, viewport: viewport)
    }

    @Test func edgesAreOnlyHiddenBeyondTheSlack() {
        let top = state(0, content: 300)
        #expect(!top.hiddenAbove && top.hiddenBelow)
        let middle = state(100, content: 300)
        #expect(middle.hiddenAbove && middle.hiddenBelow)
        let bottom = state(200, content: 300)
        #expect(bottom.hiddenAbove && !bottom.hiddenBelow)
        let nearBottom = state(197, content: 300)
        #expect(!nearBottom.hiddenBelow)
        let short = state(0, content: 80)
        #expect(!short.hiddenAbove && !short.hiddenBelow)
    }

    @Test func followsNewOutputWhileAtTheBottom() {
        var follower = ScrollFollower()
        #expect(follower.isFollowing && !follower.showsJumpButton)
        let scrolls1 = follower.update(state(0, content: 120))
        #expect(scrolls1)
        let scrolls2 = follower.update(state(20, content: 200))
        #expect(scrolls2)
        #expect(follower.isFollowing)
    }

    @Test func scrollingUpPinsAndNewOutputDoesNotMoveIt() {
        var follower = ScrollFollower()
        _ = follower.update(state(100, content: 200))
        let scrolls3 = follower.update(state(40, content: 200))
        #expect(!scrolls3)
        #expect(!follower.isFollowing && follower.showsJumpButton)
        let scrolls4 = follower.update(state(40, content: 260))
        #expect(!scrolls4)
        #expect(follower.showsJumpButton)
    }

    @Test func jumpingOrScrollingBackToTheEndFollowsAgain() {
        var follower = ScrollFollower()
        _ = follower.update(state(100, content: 200))
        _ = follower.update(state(10, content: 200))
        follower.jumpToLatest()
        #expect(follower.isFollowing && !follower.showsJumpButton)

        _ = follower.update(state(10, content: 200))
        #expect(follower.showsJumpButton)
        _ = follower.update(state(100, content: 200))
        #expect(follower.isFollowing)
    }

    @Test func clearingTheOutputFollowsAgain() {
        var follower = ScrollFollower()
        _ = follower.update(state(100, content: 200))
        _ = follower.update(state(10, content: 200))
        #expect(follower.showsJumpButton)
        _ = follower.update(state(0, content: 0))
        #expect(follower.isFollowing)
    }
}
