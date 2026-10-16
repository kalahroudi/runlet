import Foundation

public enum StreamKind: Sendable, Equatable {
    case stdout, stderr
}

public enum Outcome: Sendable, Equatable {
    case exited
    case timedOut
    case failedToLaunch(String)
}

public struct RunResult: Sendable, Equatable {
    public var exitCode: Int32?
    public var outcome: Outcome
    public var duration: TimeInterval

    public init(exitCode: Int32?, outcome: Outcome, duration: TimeInterval) {
        self.exitCode = exitCode
        self.outcome = outcome
        self.duration = duration
    }
}

public enum RunEvent: Sendable, Equatable {
    case output(StreamKind, String)
    case finished(RunResult)
}

public struct RunRequest: Sendable {
    public var executable: URL
    public var arguments: [String]
    public var workingDirectory: URL?
    public var environment: [String: String]?
    /// Seconds a program may run before it is stopped. `nil` means no limit.
    public var timeout: TimeInterval?
    /// When true the program can be sent input with `RunSession.send`. Otherwise its input is empty.
    public var interactive: Bool

    public init(executable: URL, arguments: [String] = [], workingDirectory: URL? = nil,
                environment: [String: String]? = nil, timeout: TimeInterval? = 10, interactive: Bool = false) {
        self.interactive = interactive
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeout = timeout
    }
}

/// A run in progress: what it prints, and a way to type to it.
public final class RunSession: @unchecked Sendable {
    public let events: AsyncStream<RunEvent>
    private let sendText: @Sendable (String) -> Void
    private let endInput: @Sendable () -> Void

    public init(events: AsyncStream<RunEvent>,
                send: @escaping @Sendable (String) -> Void = { _ in },
                closeInput: @escaping @Sendable () -> Void = {}) {
        self.events = events
        self.sendText = send
        self.endInput = closeInput
    }

    /// Sends text to the program as typed. Does nothing once the program has exited.
    public func send(_ text: String) { sendText(text) }
    /// Signals end of input, like pressing Ctrl-D.
    public func closeInput() { endInput() }
}

/// Runs a program and streams what it prints. Exactly one `.finished` event is sent, last.
public enum ProcessRunner {
    /// Time a program gets to exit after the terminate signal before it is killed.
    static let killGrace: TimeInterval = 1

    public static func run(_ request: RunRequest) -> AsyncStream<RunEvent> {
        start(request).events
    }

    public static func start(_ request: RunRequest) -> RunSession {
        // Writing to a program that has exited must not kill this app.
        signal(SIGPIPE, SIG_IGN)
        let input = request.interactive ? Pipe() : nil
        let clock = RunClock()
        let writer = InputWriter(input?.fileHandleForWriting, clock: clock)
        let events = AsyncStream<RunEvent> { continuation in
            let process = Process()
            process.executableURL = request.executable
            process.arguments = request.arguments
            process.currentDirectoryURL = request.workingDirectory
            process.environment = request.environment
            process.standardInput = input ?? FileHandle.nullDevice
            let stdout = Pipe(), stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let stop = StopReason()
            let start = Date()

            let readers = DispatchGroup()
            let watching = request.interactive ? clock : nil
            stream(stdout, as: .stdout, into: continuation, group: readers, clock: watching)
            stream(stderr, as: .stderr, into: continuation, group: readers, clock: watching)

            process.terminationHandler = { finished in
                writer.close()
                // Wait for both readers to reach end of file so no output is lost. A grandchild that keeps
                // a pipe open must not hold the result back forever.
                DispatchQueue.global().async {
                    _ = readers.wait(timeout: .now() + 2)
                    continuation.yield(.finished(RunResult(
                        exitCode: finished.terminationStatus,
                        outcome: stop.value ?? .exited,
                        duration: Date().timeIntervalSince(start)
                    )))
                    continuation.finish()
                }
            }

            do {
                try process.run()
            } catch {
                try? stdout.fileHandleForWriting.close()
                try? stderr.fileHandleForWriting.close()
                try? input?.fileHandleForReading.close()
                writer.close()
                continuation.yield(.finished(RunResult(
                    exitCode: nil, outcome: .failedToLaunch(error.localizedDescription), duration: 0)))
                continuation.finish()
                return
            }

            try? input?.fileHandleForReading.close()

            if let timeout = request.timeout {
                // Polls instead of sleeping once, because the clock pauses while the program waits for typing.
                DispatchQueue.global().async {
                    while process.isRunning {
                        if clock.elapsed() >= timeout {
                            stop.set(.timedOut)
                            terminate(process)
                            return
                        }
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
            }

            continuation.onTermination = { reason in
                if case .cancelled = reason, process.isRunning { terminate(process) }
            }
        }
        return RunSession(events: events, send: { writer.write($0) }, closeInput: { writer.close() })
    }

    /// Reads a pipe on its own queue until end of file, in order, and leaves the group when done.
    private static func stream(_ pipe: Pipe, as kind: StreamKind,
                               into continuation: AsyncStream<RunEvent>.Continuation, group: DispatchGroup,
                               clock: RunClock?) {
        group.enter()
        DispatchQueue.global().async {
            let handle = pipe.fileHandleForReading
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                continuation.yield(.output(kind, String(decoding: data, as: UTF8.self)))
                clock?.output(endedWithNewline: data.last == 10)
            }
            group.leave()
        }
    }

    private static func terminate(_ process: Process) {
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}

/// Remembers that a run was stopped for taking too long, so the termination handler can report it.
private final class StopReason: @unchecked Sendable {
    private let lock = NSLock()
    private var reason: Outcome?

    var value: Outcome? { lock.withLock { reason } }
    func set(_ new: Outcome) { lock.withLock { if reason == nil { reason = new } } }
}

/// Writes to a program's input on its own queue so a full pipe never blocks the caller.
private final class InputWriter: @unchecked Sendable {
    private let handle: FileHandle?
    private let clock: RunClock
    private let queue = DispatchQueue(label: "runlet.input")
    private var closed = false

    init(_ handle: FileHandle?, clock: RunClock) { self.handle = handle; self.clock = clock }

    func write(_ text: String) {
        clock.resume()
        queue.async { [self] in
            guard !closed, let handle else { return }
            try? handle.write(contentsOf: Data(text.utf8))
        }
    }

    func close() {
        clock.resume()
        queue.async { [self] in
            guard !closed, let handle else { return }
            closed = true
            try? handle.close()
        }
    }
}

/// Counts how long a program has really been running. It pauses while the program has printed a prompt
/// (output without a final newline) and is waiting for the person to answer.
final class RunClock: @unchecked Sendable {
    private let lock = NSLock()
    private let start = Date()
    private var pausedSince: Date?
    private var pausedTotal: TimeInterval = 0

    func output(endedWithNewline: Bool) {
        lock.withLock {
            if endedWithNewline { resumeLocked() } else if pausedSince == nil { pausedSince = Date() }
        }
    }

    func resume() { lock.withLock { resumeLocked() } }

    func elapsed() -> TimeInterval {
        lock.withLock {
            let now = Date()
            return now.timeIntervalSince(start) - pausedTotal - (pausedSince.map { now.timeIntervalSince($0) } ?? 0)
        }
    }

    private func resumeLocked() {
        guard let since = pausedSince else { return }
        pausedTotal += Date().timeIntervalSince(since)
        pausedSince = nil
    }
}
