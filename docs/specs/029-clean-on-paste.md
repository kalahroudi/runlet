# Spec 029: Clean on paste

Status: Draft
Depends on: 005, 006, 026, 028
Size estimate: M (about 400 lines including tests)

## Why
Spec 028 made runs forgiving: a pasted block with a stray indent now runs. But the box still shows the damage (fences, `>>>` prompts, curly quotes), and those cannot be fixed silently at run time because fixing them changes line numbers. Cleaning at paste time removes them where the person can see it, before they run anything, and ⌘Z gives the original paste back.

## Scope
- Paste in the **popover code box**, the **editor** (main window) and the editor's **fallback text box** goes through `CodeCleaner.clean(_:mode: .paste)` (spec 028).
- A one-line notice under the code after a paste that changed something: "Cleaned pasted code: indent removed, markdown fence removed. ⌘Z to undo." It disappears on the next edit.
- The popover code box becomes a small text view that can intercept paste (SwiftUI `TextEditor` cannot), with the same look as today.

## Non-goals
- Cleaning typed text, drag and drop, or text loaded from a snippet. Only paste cleans.
- A setting to turn cleaning off. If people ask, it is a small follow-up.
- Changing the rules or the cleaner itself (spec 028).
- Other languages (specs 016 and 017).

## Behavior
- Paste that needs no cleaning behaves exactly as today, with no notice.
- When cleaning changes something, the pasted text is replaced at the cursor (or over the selection) by the cleaned text. Dedent looks at the pasted text alone, as in spec 028.
- **Undo gives back the original paste.** The original text is inserted first and the cleaned text replaces it as a second, separate undo step, so one ⌘Z shows exactly what was on the clipboard and a second removes the paste.
- **Popover and fallback box:** an `NSTextView` subclass overrides `paste(_:)`. It reads the plain text from the pasteboard, cleans it, and inserts both steps through the text view's undo manager. The view keeps the monospaced font, transparent background, hidden scrollers and growth rules of the current box.
- **Editor:** the page intercepts the `paste` event, cancels it and sends the clipboard text to Swift through a message with a reply (`WKScriptMessageHandlerWithReply`). Swift answers with `{text, notice}`. The page then inserts the original and the cleaned text as two history events. If Swift does not answer, the page inserts the original text unchanged.
- The notice is held in `QuickRunModel` (`pasteNotice`), shown in the popover under the code and in the window under the editor, and cleared when the text changes by anything other than the paste itself.
- Pasting a single word or short line is almost never changed by the cleaner. A rule that fires on one line (a lone leading space, a lone fence) still applies.

## Acceptance criteria
- [ ] Pasting an indented block, a fenced block and a `>>>` transcript into the popover box yields code that runs, with the notice shown.
- [ ] The same three pastes into the editor yield the same result.
- [ ] In both, one ⌘Z restores exactly what was pasted, and a second removes it.
- [ ] Pasting clean code changes nothing and shows no notice. Typing never cleans.
- [ ] Pasting into the middle of existing code cleans only the pasted text.
- [ ] The popover box looks and grows as before (4 to 9 lines, no scrollbar), and ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z still work.
- [ ] The editor still sets text from Swift without echoing `onChange`, and autosave sees the cleaned text.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for the model: `QuickRunModel.cleanPaste(_:)` returns the cleaned text and sets and clears `pasteNotice`; clean input returns the same text and no notice.
- The editor bundle is rebuilt with `scripts/build-editor.sh` (paste handler); its hash is updated in the PR.
- Manual, listed in the PR: the three pastes into the popover and the editor, undo twice, paste into the middle of code, clean paste with no notice, light and dark look unchanged.

## Risks and open questions
- Replacing `TextEditor` in the popover is the riskiest part: caret, selection, undo and growth must behave as before. Mitigation: keep the change to a thin `NSViewRepresentable` and check by hand.
- The editor round trip to Swift is asynchronous, so there is a few milliseconds between ⌘V and the text appearing. If it ever feels slow, port the cleaner to JavaScript (a second copy of the rules, which we would rather avoid).
- Two undo steps (original, then cleaned) mean ⌘Z shows the damaged text for a moment. This is on purpose, so the person can see what was removed and can stop there.
