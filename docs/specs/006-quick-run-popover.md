# Spec 006: Quick run popover

Status: In progress
Depends on: 002, 004, 022
Size estimate: M (about 450 lines including tests)

## Why
This is the first screen that looks like the product. After this spec a person clicks the menu bar icon, pastes code, sees the language recognised, presses Run and reads the result in the same popover. Every run is saved as a snippet, and recent snippets are one click away. It replaces the temporary "Try it" scratch box from spec 002 and gives the popover the layout of the approved mock.

## Scope
- The popover layout from the mock: a code box with a Run button, a language row, a one-line detection notice, a small output area, a Recent list and a footer.
- Language detection from pasted code, as a tested function in `RunLetCore`.
- Saving every run as a snippet through `SnippetStore` (spec 004), and a Recent list of the newest snippets.
- Removing the scratch box and its runner wrapper, keeping the run logic (renamed and moved to the new view model).
- Styling from the visual kit (spec 022).

## Non-goals
- Languages other than Python run (specs 016 and 017). Detection recognises more languages so the app can say so plainly, but only Python runs.
- Search across snippets. The mock's field is "paste code or search"; here it is a code box only. Search is a later spec.
- The Capture button and the connected-agents count in the footer (specs 012, 013, 015). They are not shown yet.
- Syntax highlighting. The popover uses a plain monospaced box until the editor in spec 005. The full window editor is spec 005.
- Tags such as "Agent" on recent snippets (spec 010).
- Managed Python (spec 003). A Python 3 found on the Mac is still used, with the same missing-Python message as today.

## Behavior
### Layout, top to bottom (follows the mock)
1. Header row: a **Python** chip (the default, selected), the detected language chip when it is not Python, a **More ▾** menu holding every other runtime (shown as "soon", not clickable), a New icon when the box has text, and the primary **▶ Run** button (⌘↵). While running it becomes **Stop**.
2. Detection line, one line, in the ok colour: "✓ Detected Python from what you pasted". When another language is detected: "Looks like Go. Only Python runs for now." and Run is disabled. Nothing is shown for an empty box or when nothing is recognised, and Run then assumes Python.
3. One code card: the code box (4 to 9 lines, grows, then scrolls without a visible scrollbar), then the output (stderr in red) and the status line (`✓ Finished in 38 ms`) inside the same card.
4. **Recent**: the 4 newest snippets (language dot, title, relative time). Clicking one loads it into the code box.
5. Footer strip: the version on the left, and icon-only buttons on the right: Open in window, Settings (gear) and Quit (power), each with a tooltip. No text buttons.

### Keyboard and input
- The app installs an Edit menu so ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z work in the code box. A menu bar app has none by default.
- Runs have no keyboard input yet. Code that calls `input()` fails with `EOFError`, and the status area says so plainly. Real input (a stdin field) is a later spec.

### Running and saving
- Run saves first, then runs. If the box belongs to a snippet, that snippet is updated. Otherwise a new one is created, titled from the first non-empty line.
- Edits are not saved until Run is pressed (autosave arrives with the editor in spec 005). Closing the popover keeps the box text for the rest of the session.
- Starting a new paste into an empty box starts a new snippet. A "New" link above the box clears it and forgets the current snippet.

### Language detection
```swift
public enum Language: String, CaseIterable { case python, javascript, typescript, go, rust }
public enum LanguageDetector { public static func detect(_ source: String) -> Language? }
```
Rules, checked in this order (a port of the mock): Go (`func … {` or `package main`), Rust (`fn … {` or `let mut`), TypeScript (`: string`, `: number` or `interface`), JavaScript (`const`, `=>` or `console.log`), Python (`def`, `import`, `print(`). Text under 10 characters returns nil. First match wins.

## Acceptance criteria
- [x] Detection returns the expected language for a sample of each of the five, and nil for short or unrecognised text.
- [ ] Pasting Python shows "Detected Python…" and selects the Python chip. Pasting Go shows the "Only Python runs for now" line and disables Run.
- [ ] Run (⌘↵) runs the code and streams output, stderr in red, with the status line from spec 002. `while True: pass` is stopped by Stop and by the 10 s limit.
- [x] Every run leaves a snippet on disk. Running again after editing a loaded snippet updates it and does not create a second one.
- [ ] Recent shows the 4 newest snippets with relative times, and clicking one loads its code.
- [x] "New" clears the box and the next Run creates a new snippet.
- [ ] Without a Python 3 on the Mac, the existing message is shown and Run is disabled.
- [x] The scratch box and `ScratchRunner` no longer exist.
- [ ] The popover looks like the mock in light and dark, with a side-by-side screenshot in the PR, and the product owner confirms it.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for `LanguageDetector` (each language, order of precedence, short text), for relative time formatting, and for the run-and-save rule (new versus update) in a view model that takes a `SnippetStore` and a runner closure, so no real process is needed.
- Manual: the paste, run, stop, recent and light/dark checks above, listed in the PR. Screenshots are rendered the same way as for spec 022.

## Risks and open questions
- Pasted text in a plain monospaced box has no highlighting, which will feel basic next to the mock. Accepted by the product owner, because the editor (spec 005) is already in the pipeline, so this is not a gap.
- Detection by regular expression is crude (a Python file containing `const` in a string would be misread). Python is the default when nothing else matches, and the person can still run it. Better detection is a later spec.
- "Saved on Run only" means a crash before Run loses edits. Accepted by the product owner. Autosave in spec 005 removes this.
- Relative time for older snippets: use "Mon" style names within a week, then a short date.
