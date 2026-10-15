import Testing
@testable import RunLetCore

private final class FakeWindow: ManagedWindow {
    var isClosed = false
    var frontCount = 0
    func bringToFront() { frontCount += 1 }
}

@Suite struct WindowCoordinatorTests {
    @Test func showingTwiceCreatesOneWindow() {
        var created: [FakeWindow] = []
        let coordinator = WindowCoordinator<FakeWindow> {
            let w = FakeWindow(); created.append(w); return w
        }
        coordinator.show()
        coordinator.show()
        #expect(created.count == 1)
        #expect(created[0].frontCount == 2)
    }

    @Test func showingAfterCloseCreatesANewWindow() {
        var created: [FakeWindow] = []
        let coordinator = WindowCoordinator<FakeWindow> {
            let w = FakeWindow(); created.append(w); return w
        }
        coordinator.show()
        created[0].isClosed = true
        coordinator.show()
        #expect(created.count == 2)
    }
}
