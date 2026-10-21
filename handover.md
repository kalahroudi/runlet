# Handover

State as of 2026-10-21. Read `CLAUDE.md` and `docs/specs/README.md` first; the workflow is strict (one approved spec = one PR, under about 500 lines, update the spec's status and criteria in the same PR).

## Working agreement
- The product owner merges every PR. Do not use `gh pr merge --admin` (the ruleset requires a PR and it is denied). After a merge, `git checkout main && git pull origin main`, then `./scripts/install.sh` (the first `open` often prints error -600/-609; run `open /Applications/RunLet.app` and check with `pgrep -lf RunLet.app`).
- Do not start a spec until its status is `Approved` (the owner says "approved NNN"). Write the next spec as a draft PR, wait for merge and approval, then build on a `build/NNN-...` branch.
- No git worktrees outside the repo (stale ones in the home folder annoyed the owner).
- Sign-off lines: commits end with the Co-Authored-By line, PR bodies with the Claude Code line, as in recent history.
- Roadmap rows in `docs/specs/ROADMAP.md` conflict easily when two PRs touch them; merge `origin/main` and keep rows in numeric order.

## Where things stand
| Spec | Status |
|---|---|
| 001, 004, 022, 024, 025, 005, 006, 026, 027, 028 | Done |
| 029 Clean on paste | Built, PR #34 open, waiting for the owner's manual checks and merge |
| 020 Update from the app, 023 Native popover | In progress: code merged, manual criteria never confirmed by the owner |
| 002 (runner core), 003 Managed Python, 007+ | Not started. 007 needs 003 (managed Python) |

### PR #34 (Spec 029) manual checks still owed by the owner
1. Paste an indented block, a fenced block and a `>>>` transcript into the popover and the main window editor: clean code plus a notice, ⌘Z twice steps back (first the original paste, then before it).
2. Clean paste shows no notice. The popover box looks and grows as before (4 to 9 lines, no scrollbar).
3. Then tick the criteria in `docs/specs/029-clean-on-paste.md`, set it Done, and mark the roadmap row (done) in a small docs PR.

### Open questions for the owner
- Should a snippet's title follow the first line of its code as it is edited? Today it is fixed at creation (an old snippet showed a stray trailing ".").
- Specs 020 and 023 manual criteria: ask what has been tried, then tick or fix.
- Stale local and remote branches from merged PRs could be pruned (not yet asked).

## How the app is built
- Swift package: `RunLetCore` (logic, tested), `RunLet` (app), `RunLetCoreTests` (Swift Testing, 83 tests). `swift test` works with Xcode installed.
- `scripts/build.sh` compiles with `swiftc` only: the Core module, then `Sources/RunLet/*.swift` and `Sources/RunLet/Style/*.swift`. It copies Info.plist, icon, Fonts and `Resources/editor`, embeds the commit and ad-hoc signs. New Swift files are picked up by glob.
- The editor is CodeMirror 6 in a WKWebView. The bundle in `Resources/editor` is committed; rebuild with `scripts/build-editor.sh` after changing `editor/src/main.js` (needs Node) and commit the result.
- The in-app updater is source based (needs `install.json`, a main checkout on `main`, clean tree).

### Key pieces
- `ProcessRunner` / `PythonRunner`: child process with streaming events, interactive stdin (`RunSession`), time limit that pauses while a prompt waits (`RunClock`), setting `timeLimit` (default 60 s).
- `QuickRunModel` (`@MainActor`, shared by popover and window): save on run, Recent, snippets list, output cap, `pasteNotice`. Runs a cleaned copy (`CodeCleaner` run mode, silent).
- `CodeCleaner` (spec 028): indent, fences, `>>>` prompts, odd characters, mixed tabs, curly quotes. Paste mode may remove lines; run mode never changes the line count.
- Paste: `PasteTextView` (NSTextView subclass, popover and fallback box) and the editor's `paste` handler (script message with reply). The original text goes in first, the cleaned text replaces it as a second undo step.
- Scrolling: `StyledScrollView` with edge fades and "Jump to latest", `.noScrollers()` AppKit introspection (SwiftUI's `.scrollIndicators(.hidden)` is ignored when macOS shows scroll bars always).
- Look: palette and fonts from `docs/mock/runlet.html` (`Palette.swift`, `Style/`). Capture shortcut is ⌃⌥C; never ⌘⇧R.

## Tooling limits worth knowing
- UI cannot be seen live from the assistant. Offscreen harness windows do not run `requestAnimationFrame` or SwiftUI preferences, which has led to false conclusions before. Ask the owner for a screenshot when a visual bug is reported.
- Do not assume a fix works until the owner confirms it in the installed app.

## Suggested next steps
1. Get the owner's verdict on #34, then the small docs PR to mark 029 Done.
2. Resolve 020 and 023 with the owner.
3. Next roadmap work: 003 Managed Python (unblocks 007 Missing packages), then 008 Sandbox, 009 Preview, 010 MCP. Write each spec as a draft PR first.
