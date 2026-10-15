# Spec 002: Runner core

Status: Approved
Depends on: 001
Size estimate: M (about 300 lines including tests)

## Why
Nothing in RunLet matters until it can run code. This spec adds the engine that runs a program as a child process, streams what it prints, stops it when it takes too long, and reports how it ended. It also adds a small scratch box in the popover so the engine can be tried by hand. The scratch box is temporary and is replaced by the real editor (spec 005) and quick-run popover (spec 006).

## Scope
- `ProcessRunner`: run any executable with arguments and stream events.
- `PythonRunner`: write a Python source string to a temporary `main.py`, run it with a Python 3 interpreter found on this Mac, delete the temporary folder afterwards.
- A scratch area in the popover: a text box, Run and Stop buttons, streamed output with errors in red, and a status line.

## Non-goals
- Managed Python, virtual environments or package installs (spec 003).
- Sandboxing, network or file limits (spec 008).
- Other languages (specs 016 and 017).
- Saving anything (spec 004).
- Killing grandchild processes a program starts. Only the program itself is stopped.
- Perfect handling of a multi-byte character split across two output chunks. Such a character may show as a replacement mark.

## Behavior
### ProcessRunner (in `RunLetCore`)
```swift
public struct RunRequest { executable: URL; arguments: [String]; workingDirectory: URL?; environment: [String: String]?; timeout: TimeInterval }
public enum StreamKind { case stdout, stderr }
public enum Outcome: Equatable { case exited, timedOut, failedToLaunch(String) }
public struct RunResult: Equatable { exitCode: Int32?; outcome: Outcome; duration: TimeInterval }
public enum RunEvent: Equatable { case output(StreamKind, String); case finished(RunResult) }
ProcessRunner.run(_ request: RunRequest) -> AsyncStream<RunEvent>
```
- Output arrives as it is produced, not only at the end.
- Exactly one `.finished` event is sent, last.
- Standard input is empty, so a program that waits for input ends instead of hanging.
- When the timeout passes, the program gets a terminate signal, and a kill after one more second if it is still running. The outcome is `.timedOut`.
- When the task consuming the events is cancelled, the program is terminated. There is no result to report in that case. Leaving the loop early without cancelling does not stop the program.
- If the program cannot start, the single event is `.finished` with `.failedToLaunch(reason)`.

### PythonRunner (in `RunLetCore`)
- `PythonRunner.findInterpreter()` checks `/opt/homebrew/bin`, `/usr/local/bin`, the directories in `PATH`, then `/usr/bin`, for an executable `python3`, and returns the first.
- `PythonRunner.run(source:interpreter:timeout:)` runs `python3 -u main.py` in a fresh temporary folder, with `PYTHONDONTWRITEBYTECODE=1` and `PYTHONIOENCODING=utf-8`. Default timeout is 10 seconds. The folder is removed after the run ends.

### Scratch area (in the popover)
- A monospaced text box starting with `print("Hello from RunLet")`.
- Run (⌘↵) starts a run and clears the previous output. While running, Run becomes Stop.
- Output streams in; stderr is red.
- Status line: `Finished in 38 ms`, `Exited with code 1 in 41 ms`, `Stopped after 10 s (time limit)` or `Stopped`.
- If no Python 3 is found: "Python 3 was not found. Install it with `brew install python`. RunLet will manage Python for you in a later update."

## Acceptance criteria
- [ ] A shell command that prints to stdout and stderr produces both kinds of events, in order of arrival, and a `.finished` with exit code 0.
- [ ] A command that exits with code 3 reports exit code 3 and outcome `.exited`.
- [ ] A command that sleeps longer than the timeout is stopped, reports `.timedOut`, and returns in well under the sleep time.
- [ ] Cancelling the task that consumes the events terminates the program.
- [ ] A nonexistent executable reports `.failedToLaunch`.
- [ ] Python: `print("hi")` outputs `hi` and exits 0. A script that raises prints a traceback on stderr and exits 1. Both tests are skipped when no interpreter is found.
- [ ] The temporary folder no longer exists after a Python run.
- [ ] In the app, Run shows streamed output, a runaway loop (`while True: pass`) is stopped by Stop and also by the time limit, and an error shows in red.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for `ProcessRunner` using `/bin/sh`, so they do not depend on Python.
- Swift Testing tests for `PythonRunner`, skipped without an interpreter.
- Manual: the scratch-area checks above, listed in the PR.

## Risks and open questions
- `/usr/bin/python3` on a Mac without developer tools triggers an install dialog when run. Preferring Homebrew or other installs first reduces this. Spec 003 removes the problem.
- Terminating only the child can leave grandchildren running. Revisit with the sandbox spec.
