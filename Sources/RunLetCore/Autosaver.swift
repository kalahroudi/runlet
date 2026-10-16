import Foundation

/// Saves text a short while after the last change. A burst of changes causes one save.
@MainActor
public final class Autosaver: ObservableObject {
    public enum State: Equatable {
        case idle
        case pending
        case saved(Date)
        case failed(String)
    }

    /// Runs `work` after `delay` seconds and returns a function that cancels it.
    public typealias Scheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    @Published public private(set) var state = State.idle

    private let delay: TimeInterval
    private let schedule: Scheduler
    private let save: @MainActor (String) throws -> Void
    private let now: () -> Date
    private var latest: String?
    private var cancelPending: (() -> Void)?

    public init(delay: TimeInterval = 0.3, schedule: Scheduler? = nil,
                now: @escaping () -> Date = Date.init, save: @escaping @MainActor (String) throws -> Void) {
        self.delay = delay
        self.schedule = schedule ?? Autosaver.realSchedule
        self.now = now
        self.save = save
    }

    /// Call on every edit.
    public func change(_ text: String) {
        latest = text
        state = .pending
        cancelPending?()
        cancelPending = schedule(delay) { [weak self] in self?.flush() }
    }

    /// Saves now if there is something waiting. Call when the editor closes.
    public func flush() {
        cancelPending?()
        cancelPending = nil
        guard let text = latest else { return }
        latest = nil
        do {
            try save(text)
            state = .saved(now())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public static let realSchedule: Scheduler = { delay, work in
        let task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled { work() }
        }
        return { task.cancel() }
    }
}
