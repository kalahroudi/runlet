import Foundation
import Testing
@testable import RunLetCore

@MainActor
@Suite struct AutosaverTests {
    @MainActor final class Clock {
        var pending: [(id: Int, work: @MainActor () -> Void)] = []
        var next = 0
        var cancelled = 0
        var delays: [TimeInterval] = []

        var scheduler: Autosaver.Scheduler {
            { [self] delay, work in
                let id = next; next += 1
                delays.append(delay)
                pending.append((id, work))
                return { [self] in cancelled += 1; pending.removeAll { $0.id == id } }
            }
        }
        /// Lets the delay pass for whatever is still scheduled.
        func fire() { let due = pending; pending = []; due.forEach { $0.work() } }
    }

    struct Failure: Error, LocalizedError { var errorDescription: String? { "disk full" } }

    @Test func aBurstOfChangesSavesOnceWithTheLatestText() {
        let clock = Clock()
        var saved: [String] = []
        let saver = Autosaver(delay: 0.3, schedule: clock.scheduler) { saved.append($0) }
        saver.change("a"); saver.change("ab"); saver.change("abc")
        #expect(saved.isEmpty)
        #expect(saver.state == .pending)
        clock.fire()
        #expect(saved == ["abc"])
        #expect(clock.delays == [0.3, 0.3, 0.3])
        if case .saved = saver.state {} else { Issue.record("expected saved, got \(saver.state)") }
    }

    @Test func flushSavesAtOnceAndOnlyOnce() {
        let clock = Clock()
        var saved: [String] = []
        let saver = Autosaver(schedule: clock.scheduler) { saved.append($0) }
        saver.change("x")
        saver.flush()
        saver.flush()
        clock.fire()
        #expect(saved == ["x"])
    }

    @Test func flushWithNothingWaitingDoesNotSave() {
        var saved = 0
        let saver = Autosaver(schedule: Clock().scheduler) { _ in saved += 1 }
        saver.flush()
        #expect(saved == 0 && saver.state == .idle)
    }

    @Test func aSaveErrorIsReportedAndLaterEditsStillSave() {
        let clock = Clock()
        var fail = true
        var saved: [String] = []
        let saver = Autosaver(schedule: clock.scheduler) {
            if fail { throw Failure() }
            saved.append($0)
        }
        saver.change("one"); clock.fire()
        #expect(saver.state == .failed("disk full"))
        fail = false
        saver.change("two"); clock.fire()
        #expect(saved == ["two"])
    }
}
