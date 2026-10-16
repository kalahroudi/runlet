# Spec 028: Clean pasted code

Status: Draft
Depends on: 005, 006, 026
Size estimate: M (about 450 lines including tests)

## Why
Most code arrives by copy and paste, from chats, web pages, documents and terminals, and it arrives with damage: the whole block indented, a Markdown fence around it, `>>>` prompts from a Python shell, curly quotes, non-breaking spaces. Python then refuses to run it with an error the person did not cause (`IndentationError: unexpected indent` on a line that looks fine). RunLet should fix the damage it can fix safely, say what it did, and leave everything else alone.

## Scope
- A pure, tested function in `RunLetCore`, `CodeCleaner.clean(_:mode:)`, that returns the cleaned text and a list of what it changed.
- Two modes:
  - **paste**: runs on pasted text, may remove lines (fences, prompts).
  - **run**: runs on a copy of the box just before a run. It never adds or removes lines, so error line numbers match what the person sees.
- Cleanups, each reported by name:
  1. **Dedent**: remove the indentation shared by all non-blank lines (also when the first line is the only one that lost its indent, as when copying from the middle of a line).
  2. **Fences** (paste only): remove a leading ```` ```python ```` (or ```` ``` ````) line and a trailing ```` ``` ```` line.
  3. **Shell prompts** (paste only): remove `>>> ` and `... ` prefixes when most lines have them, and drop lines that are output (no prompt) when the text is a transcript.
  4. **Odd characters**: byte order mark, zero-width characters, and non-breaking or other Unicode spaces become normal spaces or nothing. Windows line endings become `\n`.
  5. **Mixed tabs and spaces**: when lines start with both, leading tabs become 4 spaces. Consistent tabs are left alone.
  6. **Curly quotes**: `“ ” ‘ ’` used as quotes outside strings and comments become straight quotes. Curly quotes inside a string or comment are text, and stay.
- Paste handling: the quick run popover box and the editor clean text as it is pasted. Cleaning replaces the pasted text, so ⌘Z undoes it and gives back exactly what was pasted.
- Run handling: before every run the "run" mode is applied to a copy. The box and the saved snippet are not changed by it.
- A one-line notice under the code: "Cleaned pasted code: removed indent, markdown fence. ⌘Z to undo." for a paste, and "Ran with indent removed." for a run. It disappears on the next edit.

## Non-goals
- Reformatting style (line length, quotes, spacing, imports). That needs a formatter such as ruff, which arrives with managed Python (spec 003) and is a later spec.
- Fixing real mistakes: wrong indentation inside the code, missing colons, unbalanced brackets, wrong names. Python reports those.
- Removing trailing whitespace. It never causes an error, and it can change the text inside a multi-line string.
- Other languages. Rules for them come with their specs (016, 017).
- A setting to turn cleaning off. If people ask, it is a small follow-up.

## Behavior
- Nothing changes unless there is something to clean. Typing never triggers cleaning, only a paste does.
- Cleaning is conservative: a rule applies only when it is certain it fixes damage rather than the person's content. When unsure (for example `>>>` on only some lines), do nothing.
- Order: line endings and odd characters, fences, prompts, tabs, dedent, curly quotes.
- The editor intercepts the paste, sends the pasted text to Swift, and inserts the cleaned text at the cursor in one undoable step. The popover box does the same through a text view that overrides paste.
- Pasting into a non-empty box cleans only the pasted text, but dedent looks at the pasted text alone.
- Cleaning is Python-aware only through these rules. It does not parse the code, except for a small scanner that tracks strings and comments for the curly quote rule.

## Acceptance criteria
- [ ] Tests for each cleanup: indented block, indented first line only, Markdown fence with and without a language, `>>>` and `...` transcript with output lines, BOM, zero-width and non-breaking spaces, CRLF, mixed tabs and spaces, consistent tabs untouched, curly quotes used as quotes versus inside a string or comment.
- [ ] Tests that clean text is unchanged (same string, no changes listed), and that cleaning twice gives the same result.
- [ ] Tests that "run" mode keeps the number of lines, and "paste" mode may drop fence and prompt lines.
- [ ] Pasting an indented block, a fenced block and a `>>>` transcript into the popover and into the editor yields code that runs, with the notice shown, and ⌘Z restores the original paste.
- [ ] Typing a leading space and pressing Run runs, shows "Ran with indent removed.", and leaves the box as typed.
- [ ] `for i in range(200): print(i)` with a leading space runs.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for `CodeCleaner` (pure string in, string and change list out). The paste interception in both views is checked by hand and listed in the PR.

## Risks and open questions
- Dedent or tab changes inside a multi-line string literal change the string. Accepted: dedent only removes indent shared by every non-blank line, so a string's inner layout stays consistent. Tab conversion happens only when tabs and spaces are mixed, which Python rejects anyway.
- The curly quote scanner is a small hand-written tokenizer (single and triple quotes, escapes, comments). It will not match Python's tokenizer in every corner (f-strings with nested quotes). Mitigation: when the scanner is unsure, it leaves the text alone.
- Intercepting paste in CodeMirror costs a round trip to Swift. It should take a few milliseconds. If it ever feels slow, port the cleaner to JavaScript (a second copy of the rules, which we would rather avoid).
- This could exceed 500 lines. If so, split: 028 for the cleaner and run mode, 029 for paste interception in the two views.
