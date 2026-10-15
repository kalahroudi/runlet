# Spec 005: Editor and console

Status: Draft
Depends on: 002, 004
Size estimate: M (about 450 hand-written lines including tests, excluding the vendored editor bundle)

## Why
After this spec a person can open a snippet in the main window, edit it with syntax highlighting, press Run and read the output in a console. It replaces the temporary scratch box from spec 002 in the window. It is the base that the preview pane, packages and agent specs build on.

## Scope
- A CodeMirror 6 editor in a `WKWebView`, loaded from a prebuilt bundle stored in the repo (no npm at build time).
- Python syntax highlighting, line numbers, bracket matching, ⌘/ comment toggle, light and dark themes that follow the system.
- A Swift to editor bridge: set text, get text, and a change notification (debounced 300 ms) that autosaves the snippet through the store from spec 004.
- A main window layout: editor on top, console below, a toolbar with Run (⌘↵) and Stop.
- A console that streams output from the runner in spec 002, stderr in red, with the status line from spec 002.
- Scrolling: the editor and console hide the system scrollbar. Content scrolls with trackpad, wheel and keys as usual. A thin fade at a scroll edge shows that more content exists, and the console shows a "Jump to latest" button when it is not at the bottom. The console follows new output only while it is at the bottom.

## Non-goals
- Languages other than Python (specs 016 and 017) and language detection (spec 006).
- Preview pane, number sliders, package install bar, agent editing (specs 007, 009, 010).
- Replacing the popover scratch box (spec 006 does that).
- Multiple tabs or split editors.
- Autocomplete and linting.

## Behavior
- Opening a snippet from the list loads its text into the editor. Typing saves after 300 ms of quiet. A small "Saved" indicator shows the last save.
- Run (⌘↵) saves, clears the console and runs with `PythonRunner`. While running, Run becomes Stop. Closing the window or opening another snippet while running stops the run.
- The console shows the same statuses as spec 002.
- Scroll styling: no visible scroller in either area. The edge fade is 16 pt, uses the background colour, and appears only on an edge with hidden content. "Jump to latest" is a small pill at the bottom right of the console. Keyboard and VoiceOver scrolling still work.
- Editor bridge interface (Swift): `EditorView.text` (get/set) and `onChange: (String) -> Void`.

## Acceptance criteria
- [ ] The editor shows Python with highlighting, line numbers, and matches the system light or dark appearance.
- [ ] Typing in the editor saves the snippet within about 300 ms of the last key, and reopening the snippet shows the edit.
- [ ] Run streams output into the console, stderr is red, and the status line matches spec 002.
- [ ] Stop and the 10 s time limit both end `while True: pass`.
- [ ] Neither the editor nor the console shows a scrollbar, and both still scroll by trackpad, wheel and keyboard.
- [ ] An edge fade appears only on an edge that has hidden content.
- [ ] While the console is scrolled up, new output does not move it and "Jump to latest" is shown. Pressing it scrolls to the end and hides the button.
- [ ] Closing the window while a run is active stops the program.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for the autosave debouncer and the console follow-or-pin logic (pure Swift in `RunLetCore`).
- Manual: the editor, scrolling and run checks above, listed in the PR.

## Risks and open questions
- The build uses only the Command Line Tools, so CodeMirror must be committed as a prebuilt, minified bundle. Confirm where it lives (`Sources/RunLet/Resources/editor/`) and how it is rebuilt, ideally a documented script outside the normal build.
- Spec 004 is not written. Store method names here are placeholders and will be aligned once 004 is approved.
- Hidden scrollbars hurt discoverability for mouse users. The edge fade and keyboard support are the mitigation. Revisit if testing shows people miss it.
- A web view needs to be sandbox-friendly with no network access. Load only local files.
