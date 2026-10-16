# Spec 025: Run time limit you control

Status: Draft
Depends on: 002, 006, 024
Size estimate: S (about 250 lines including tests)

## Why
Every run is stopped after 10 seconds (spec 002). That protects against runaway code, but it also cuts off slow scripts and programs that wait for the person to type (spec 024). The person can already press Stop at any moment, so the limit should be generous by default and the person's choice.

## Scope
- A **Run time limit** setting in Settings: 10 seconds, 60 seconds (default), 5 minutes, No limit. Stored in `UserDefaults`, read at the start of each run.
- A tested type in `RunLetCore` that maps the stored value to a timeout (`nil` means no limit), with unknown values falling back to 60 seconds.
- `RunRequest.timeout` becomes optional (`nil` = no limit). Existing callers keep passing a number.
- The clock does not run while the program waits for the person: it pauses when the program has printed a prompt (output that does not end in a newline) and resumes when the person sends input or ends input. A new `RunSession` method tells the runner about this, or the runner detects it from the output stream (decided during implementation, the behavior below is what is tested).
- The stopped message names the limit and where to change it: "Stopped after 60 s (time limit). Change it in Settings."

## Non-goals
- Per-snippet limits.
- A limit on memory or output size (output is already capped at 100,000 characters).
- Detecting a program that waits on input without printing a prompt. Its clock keeps running, and Stop still works.

## Behavior
- Settings, General tab, a card "Runs" with one segmented control: `10 s · 60 s · 5 min · None`.
- The popover reads the setting when Run is pressed. A change applies to the next run, not the current one.
- With **No limit**, only Stop (or the program finishing) ends a run.
- The existing summary lines stay the same, except the time-limit one gains the Settings hint above.
- Stop kills the program as today (terminate, then kill after one second).

## Acceptance criteria
- [ ] Tests for the setting type: each stored value maps to the right timeout, `nil` for No limit, and unknown or missing values give 60 seconds.
- [ ] A test shows a run with no limit is still running after a longer wait and ends when stopped.
- [ ] A test shows the clock pauses while a prompt is waiting: a program that prints a prompt and waits longer than the limit is not stopped, and one that keeps computing past the limit is.
- [ ] `RunSummary` text for the time-limit case includes the Settings hint, and existing summary tests are updated.
- [ ] The setting appears in Settings in light and dark, and changing it affects the next run.
- [ ] `while True: pass` is stopped by the limit when it is 10 s, and by Stop when it is No limit.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Risks and open questions
- Pausing the clock on "output without a newline" is a heuristic. It fits `input("Name: ")`, and misses a bare `input()`. The person can always press Stop. Product owner: accept, or should waiting for input never count at all (clock pauses whenever the input line is shown)?
- A hung program with No limit keeps running until Stop. The popover shows "Running…" with Stop visible, so it is not hidden, but closing the popover does not stop the run. Proposal: leave as is, and revisit if it bites.
