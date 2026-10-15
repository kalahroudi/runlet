import Foundation
import Testing
@testable import RunLetCore

struct Collected {
    var stdout = ""
    var stderr = ""
    var order: [OutputStream] = []
    var result: RunResult?
}

func collect(_ stream: AsyncStream<RunEvent>) async -> Collected {
    var out = Collected()
    for await event in stream {
        switch event {
        case .output(.stdout, let text): out.stdout += text; out.order.append(.stdout)
        case .output(.stderr, let text): out.stderr += text; out.order.append(.stderr)
        case .finished(let result): out.result = result
        }
    }
    return out
}

func shell(_ script: String, timeout: TimeInterval = 5) -> AsyncStream<RunEvent> {
    ProcessRunner.run(RunRequest(executable: URL(fileURLWithPath: "/bin/sh"),
                                 arguments: ["-c", script], timeout: timeout))
}

@Suite struct ProcessRunnerTests {
    @Test func streamsStdoutAndStderr() async {
        let out = await collect(shell("echo hello; echo oops 1>&2"))
        #expect(out.stdout == "hello\n")
        #expect(out.stderr == "oops\n")
        #expect(out.result?.exitCode == 0)
        #expect(out.result?.outcome == .exited)
    }

    @Test func reportsExitCode() async {
        let out = await collect(shell("exit 3"))
        #expect(out.result?.exitCode == 3)
        #expect(out.result?.outcome == .exited)
    }

    @Test func stopsAtTheTimeLimit() async {
        let out = await collect(shell("sleep 30", timeout: 0.3))
        #expect(out.result?.outcome == .timedOut)
        #expect((out.result?.duration ?? 99) < 5)
    }

    @Test func cancellingTheConsumerTerminatesTheProgram() async throws {
        let pids = AsyncStream<Int32>.makeStream()
        let consumer = Task {
            for await event in shell("echo $$; exec sleep 30") {
                if case .output(.stdout, let text) = event,
                   let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    pids.continuation.yield(pid)
                }
            }
        }
        var iterator = pids.stream.makeAsyncIterator()
        let target = try #require(await iterator.next())
        consumer.cancel()
        var alive = true
        for _ in 0..<30 where alive {
            try await Task.sleep(nanoseconds: 100_000_000)
            alive = kill(target, 0) == 0
        }
        #expect(!alive)
    }

    @Test func reportsAProgramThatCannotStart() async {
        let stream = ProcessRunner.run(RunRequest(executable: URL(fileURLWithPath: "/no/such/program")))
        let out = await collect(stream)
        guard case .failedToLaunch? = out.result?.outcome else {
            Issue.record("expected failedToLaunch, got \(String(describing: out.result))")
            return
        }
    }
}

@Suite struct RunSummaryTests {
    @Test func describesEachOutcome() {
        #expect(RunResult(exitCode: 0, outcome: .exited, duration: 0.038).summary(timeLimit: 10) == "Finished in 38 ms")
        #expect(RunResult(exitCode: 1, outcome: .exited, duration: 1.24).summary(timeLimit: 10) == "Exited with code 1 in 1.2 s")
        #expect(RunResult(exitCode: 15, outcome: .timedOut, duration: 10).summary(timeLimit: 10) == "Stopped after 10 s (time limit)")
        #expect(RunResult(exitCode: nil, outcome: .failedToLaunch("no such file"), duration: 0)
            .summary(timeLimit: 10) == "Could not start: no such file")
    }
}
