# Spec 026: Main window with Run and console

Status: Done
Depends on: 002, 004, 005, 024, 025
Size estimate: M (about 400 lines including tests)

## Why
After this spec the full window is a working playground: a list of snippets, the editor from spec 005, a Run button and a console that shows output. It is what the popover's "Open in window" opens, and the base for the preview pane, packages and agent specs.

## Scope
- Window layout from the mock: a snippet list on the left (newest first, title, relative time, New and Delete), the editor on top and the console below, and a toolbar with Run (⌘↵) and Stop.
- A console view that streams output from the runner, stderr in red, with the status line (spec 002) and an input line while a run waits for typing (spec 024).
- The same run, save and limit behavior as the popover, by sharing `QuickRunModel` or extracting a common run model.
- Opening a snippet from the popover's Recent list or "Open in window" shows that snippet in the window.

## Non-goals
- Hidden scrollbars and styled scrolling (spec 027). The console and list use the system scroller until then.
- Search across snippets, tags, folders. Other languages. Preview pane (spec 009).
- Version history (spec 014).

## Behavior
- Run saves, clears the console and runs. While running, Run becomes Stop. Closing the window or switching snippets while running stops the run.
- Selecting a snippet in the list loads it in the editor. Deleting asks for no confirmation because the snippet goes to the Trash (spec 004).
- The console follows new output. Output is capped at 100,000 characters as in the popover.
- The window remembers its size. The list width is adjustable but not remembered yet.
- The popover and the window share one box, snippet list and run (`QuickRunModel.shared`). Opening the window shows the snippet the popover has open, a run started in either shows in both, and there is nothing to keep in sync.

## Acceptance criteria
- [x] The window shows the snippet list, editor, console and toolbar, in light and dark, matching the mock layout.
- [x] Run streams output, stderr in red, status line as in the popover, and Stop and the time limit setting still end a run.
- [x] A program that calls `input()` can be answered in the console.
- [x] Switching snippets or closing the window while running stops the program.
- [x] New, Delete and selecting a snippet work, and the list updates when the popover saves a snippet.
- [x] "Open in window" from the popover opens the current snippet.
- [x] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Tests for the shared run model changes (selection, switching while running). Manual checks for layout and the run behavior, listed in the PR.

## Risks and open questions
- Sharing one box between popover and window means editing in one changes the other. Accepted: it is one "current snippet".
