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
    public var timeout: TimeInterval

    public init(executable: URL, arguments: [String] = [], workingDirectory: URL? = nil,
                environment: [String: String]? = nil, timeout: TimeInterval = 10) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeout = timeout
    }
}

/// Runs a program and streams what it prints. Exactly one `.finished` event is sent, last.
public enum ProcessRunner {
    /// Time a program gets to exit after the terminate signal before it is killed.
    static let killGrace: TimeInterval = 1

    public static func run(_ request: RunRequest) -> AsyncStream<RunEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = request.executable
            process.arguments = request.arguments
            process.currentDirectoryURL = request.workingDirectory
            process.environment = request.environment
            process.standardInput = FileHandle.nullDevice
            let stdout = Pipe(), stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let stop = StopReason()
            let start = Date()

            stream(stdout, as: .stdout, into: continuation)
            stream(stderr, as: .stderr, into: continuation)

            process.terminationHandler = { finished in
                for (pipe, kind) in [(stdout, StreamKind.stdout), (stderr, .stderr)] {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if let rest = try? pipe.fileHandleForReading.readToEnd(), !rest.isEmpty {
                        continuation.yield(.output(kind, String(decoding: rest, as: UTF8.self)))
                    }
                }
                continuation.yield(.finished(RunResult(
                    exitCode: finished.terminationStatus,
                    outcome: stop.value ?? .exited,
                    duration: Date().timeIntervalSince(start)
                )))
                continuation.finish()
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.finished(RunResult(
                    exitCode: nil, outcome: .failedToLaunch(error.localizedDescription), duration: 0)))
                continuation.finish()
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + request.timeout) {
                guard process.isRunning else { return }
                stop.set(.timedOut)
                terminate(process)
            }

            continuation.onTermination = { reason in
                if case .cancelled = reason, process.isRunning { terminate(process) }
            }
        }
    }

    private static func stream(_ pipe: Pipe, as kind: StreamKind,
                               into continuation: AsyncStream<RunEvent>.Continuation) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                continuation.yield(.output(kind, String(decoding: data, as: UTF8.self)))
            }
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
