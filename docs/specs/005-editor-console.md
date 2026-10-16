# Spec 005: Code editor

Status: Done
Depends on: 004
Size estimate: M (about 400 hand-written lines including tests, excluding the vendored editor bundle)

> Spec 005 was split. It was "Editor and console" in one spec. It is now three: this one (the editor), [026](026-main-window-console.md) (the window with Run and a console) and [027](027-styled-scrolling.md) (hidden scrollbars with styled scrolling).

## Why
Everything after the quick run popover needs a real code editor: highlighting, line numbers, light and dark themes, and snippets that save as you type. This spec delivers the editor as a reusable view and nothing else, so its riskiest part, vendoring CodeMirror without npm in the app build, is reviewed alone.

## Scope
- A CodeMirror 6 editor in a `WKWebView`, loaded from a prebuilt bundle stored in the repo at `Resources/editor/`. The app build never needs npm.
- A documented script, `scripts/build-editor.sh`, that rebuilds the bundle from `editor/` sources with npm. It is run by hand when the editor changes, and its output is committed. It is not part of CI or `scripts/build.sh`.
- Python highlighting, line numbers, bracket matching, ⌘/ comment toggle, undo and redo, and light and dark themes that follow the app's appearance setting (spec 022) and use the palette colours.
- A Swift view `EditorView` with `text` (get and set), `onChange: (String) -> Void` and a way to move focus into it.
- Autosave: a tested debouncer in `RunLetCore` that saves the snippet through `SnippetStore` 300 ms after the last change, and saves at once when the editor is closed.
- The main window (currently a placeholder) shows the editor for the newest snippet, so the view can be used and checked. Run, console and the snippet list come in spec 026.

## Non-goals
- Run button and console (spec 026). Hidden scrollbars and styled scrolling (spec 027). The editor keeps the system scroller until then.
- Languages other than Python (specs 016 and 017). Autocomplete and linting. Tabs and split editors.
- The popover code box. It stays a plain text box (spec 006).

## Behavior
- The editor loads only local files. The web view has no network access and no remote content.
- Text changes in the editor reach Swift through `onChange`. Setting `text` from Swift does not send `onChange` back.
- A small "Saved" indicator in the window shows the time of the last save, and "Saving…" while a change is waiting.
- If the editor fails to load, the window shows a plain text box with the same text and a one-line notice, so work is never lost.
- The theme follows Light, Dark or System from Settings, including when it changes while the window is open.

## Acceptance criteria
- [x] The editor shows Python with highlighting and line numbers, and matches the app's light or dark appearance.
- [x] Typing saves the snippet within about 300 ms of the last key, and reopening the app shows the edit.
- [x] The debouncer has tests: many changes in a burst cause one save, a final flush saves at once, and a save error is reported.
- [x] `EditorView.text` can be set from Swift without echoing `onChange`, and ⌘/ toggles comments.
- [x] Changing Appearance in Settings changes the open editor's theme.
- [x] If the bundle is missing, the fallback text box appears and text still saves.
- [x] `scripts/build-editor.sh` reproduces the committed bundle (documented in the script header), and the app builds with `./scripts/build.sh` on a machine without npm.
- [x] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for the autosave debouncer (time injected, no real waiting).
- Manual: highlighting, themes, comment toggle, save and reopen, fallback with the bundle renamed. Listed in the PR.

## Risks and open questions
- Bundle size: CodeMirror with the Python language is about 300 to 400 kB minified. Acceptable, as the fonts already take about 790 kB. Confirm.
- The bundle is committed, so the reviewer cannot read it. Mitigation: the build script, a pinned `package-lock.json` under `editor/`, and a note in the PR with the bundle's size and hash.
- `WKWebView` startup takes a moment. The editor shows the fallback text instantly and swaps when ready, or the window shows a blank editor background for under a second. Decide during build; either is fine.
