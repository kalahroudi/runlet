# Spec 027: Styled scrolling

Status: Done
Depends on: 026
Size estimate: S (about 250 lines including tests)

## Why
System scrollbars look cheap against the mock. Where content scrolls, the app hides the scrollbar and offers a quiet, styled way to see that there is more.

## Scope
- Applies to the editor, the console, the snippet list and the popover output.
- No visible scrollbar. Scrolling still works with trackpad, wheel and keyboard, and VoiceOver can scroll.
- A 16 pt fade, in the background colour, on an edge that has hidden content.
- A "Jump to latest" pill at the bottom right of the console when it is scrolled up. The console follows new output only while it is at the bottom.
- The follow-or-pin logic as a small tested type in `RunLetCore`.

## Non-goals
- Custom scroll physics or custom scroll bars you can drag. Horizontal scrolling styling beyond hiding the bar.

## Behavior
- The fade appears only on an edge with hidden content and disappears at the end of the content.
- New output while scrolled up does not move the console. The pill shows, and pressing it scrolls to the end and hides the pill.
- The editor's scroller is hidden through its theme, the other areas through SwiftUI.

## Acceptance criteria
- [x] No scrollbar shows in the editor, console, list or popover output, and all still scroll by trackpad, wheel and keyboard.
- [x] A fade shows only on an edge with hidden content.
- [x] While the console is scrolled up, new output does not move it and "Jump to latest" is shown. Pressing it scrolls to the end and hides it.
- [x] The follow-or-pin type has tests (at bottom follows, scrolled up pins, pressing the pill follows again).
- [x] `swift test` and `./scripts/build.sh` pass in CI.

## Risks and open questions
- Hidden scrollbars hurt discoverability for mouse users. The fade and keyboard support are the mitigation. Revisit if people miss it.
