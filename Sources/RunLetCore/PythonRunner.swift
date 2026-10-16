import Foundation

/// Runs Python source with a Python 3 found on this Mac. Managed Python replaces this later.
public enum PythonRunner {
    public static func findInterpreter(
        searchPath: [String] = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
    ) -> URL? {
        let directories = ["/opt/homebrew/bin", "/usr/local/bin"] + searchPath + ["/usr/bin"]
        return directories
            .map { URL(fileURLWithPath: $0).appendingPathComponent("python3") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public static func run(source: String, interpreter: URL, timeout: TimeInterval? = 10) -> AsyncStream<RunEvent> {
        start(source: source, interpreter: interpreter, timeout: timeout).events
    }

    /// Like `run`, but the program can be typed to through the returned session.
    public static func start(source: String, interpreter: URL, timeout: TimeInterval? = 10,
                             interactive: Bool = false) -> RunSession {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("runlet-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try source.write(to: folder.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        } catch {
            return RunSession(events: AsyncStream { continuation in
                continuation.yield(.finished(RunResult(
                    exitCode: nil, outcome: .failedToLaunch(error.localizedDescription), duration: 0)))
                continuation.finish()
            })
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONIOENCODING"] = "utf-8"
        let inner = ProcessRunner.start(RunRequest(
            executable: interpreter, arguments: ["-u", "main.py"],
            workingDirectory: folder, environment: environment, timeout: timeout, interactive: interactive))

        let events = AsyncStream<RunEvent> { continuation in
            let forwarding = Task {
                for await event in inner.events { continuation.yield(event) }
                try? FileManager.default.removeItem(at: folder)
                continuation.finish()
            }
            continuation.onTermination = { _ in forwarding.cancel() }
        }
        return RunSession(events: events, send: { inner.send($0) }, closeInput: { inner.closeInput() })
    }
}
