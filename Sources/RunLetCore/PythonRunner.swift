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

    public static func run(source: String, interpreter: URL, timeout: TimeInterval = 10) -> AsyncStream<RunEvent> {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("runlet-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try source.write(to: folder.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        } catch {
            return AsyncStream { continuation in
                continuation.yield(.finished(RunResult(
                    exitCode: nil, outcome: .failedToLaunch(error.localizedDescription), duration: 0)))
                continuation.finish()
            }
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONIOENCODING"] = "utf-8"
        let events = ProcessRunner.run(RunRequest(
            executable: interpreter, arguments: ["-u", "main.py"],
            workingDirectory: folder, environment: environment, timeout: timeout))

        return AsyncStream { continuation in
            let forwarding = Task {
                for await event in events { continuation.yield(event) }
                try? FileManager.default.removeItem(at: folder)
                continuation.finish()
            }
            continuation.onTermination = { _ in forwarding.cancel() }
        }
    }
}
