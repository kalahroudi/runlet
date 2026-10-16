# Spec 024: Interactive input for runs

Status: Draft
Depends on: 002, 006
Size estimate: S (about 250 lines including tests)

## Why
Code that calls `input()` fails today with `EOFError`, because a run has no keyboard. Beginner Python is full of `input()`, so the quick run popover has to support it: the program prints its prompt, the person types an answer, the program carries on.

## Scope
- `ProcessRunner` gets a way to send text to the running program's standard input, and to close it.
- `RunRequest` gains `interactive: Bool` (default false, so existing callers and tests behave as before).
- While a run is in progress, the output area of the quick run popover shows an input line under the output. Enter sends the typed text plus a newline and echoes it into the output. Prompts without a trailing newline (`Some text: `) appear as soon as they are printed.
- ⌘D (or a small "End input" control) closes standard input, so `sys.stdin.read()` finishes.
- Removes the "waits for typed input" note from spec 006, since it no longer applies.

## Non-goals
- A full terminal (colours, cursor control, line editing). Plain lines only.
- Input in the full window console (spec 005 reuses this runner API later).
- Piping a file or preset input into a run.

## Behavior
- A run that does not read input behaves exactly as today.
- The input line is visible only while running. It is focused automatically as soon as the program has printed something that does not end in a newline, or on a click.
- Text sent is shown in the output in the normal colour, so the transcript reads like a terminal session.
- The time limit (10 s) still applies, and does not pause while waiting for the person. Stop works at any time.
- If the program has already exited, sending does nothing and does not crash (write errors are ignored).
- Python prints prompts through a buffer, so the runner already starts it unbuffered (`-u`).

## Acceptance criteria
- [ ] A test runs `sh -c 'read a; echo got:$a'` interactively, sends a line, and sees `got:` and the line back.
- [ ] A test sends input after the program has exited and nothing crashes.
- [ ] A test closes input and a program reading to end of file finishes.
- [ ] Non-interactive runs still get an empty standard input (existing tests unchanged and green).
- [ ] The sample with two `input()` calls and an `int()` conversion runs to the end in the popover when the answers are typed, and shows both prompts.
- [ ] Stop and the 10 s limit still end a run that is waiting for input.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Risks and open questions
- A 10 s limit is short for someone typing. Proposal: the limit applies to time spent running, and waiting for input counts too for now. Revisit when settings can change the limit. The product owner decides.
