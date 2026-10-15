# Spec 023: Native popover

Status: In progress
Depends on: 001, 022
Size estimate: S (about 150 lines)

## Why
The popover now floats under the menu bar like a plain panel. The approved mock, and well-made menu bar apps, show it attached to the icon with an arrow pointing at it. After this spec RunLet's popover is anchored to its icon with that arrow, closes when you click elsewhere or press Esc, and nothing else about the app changes.

## Scope
- Replace SwiftUI `MenuBarExtra` with a menu bar item (`NSStatusItem`) and a native popover (`NSPopover`) that shows `PopoverView`.
- The popover opens below the icon with its arrow pointing at it, and closes on a click outside, on Esc, and when the icon is clicked again.
- Opening "Open in window", "Settings…" or "Quit" from the popover closes it first.
- The app is started by a small AppKit entry point instead of a SwiftUI `App`.

## Non-goals
- Changing the popover's contents or layout (spec 006).
- A right-click menu on the icon, a global shortcut to open it (spec 015), or a badge on the icon for updates.
- A custom arrow or custom popover chrome. The arrow and material are the system's.

## Behavior
- The icon is the same SF Symbol as today, drawn as a template image so it follows the menu bar's colour.
- Clicking the icon opens the popover and brings RunLet to the front so typing goes straight into the box. Clicking again closes it.
- The popover's background is the system material, so the arrow and the body match in light and dark. The cards, buttons and footer from spec 022 sit on top of it.
- The update check on open (spec 020) still runs each time the popover is shown.
- The app stays menu-bar-only until a window is opened, as before.

## Acceptance criteria
- [x] Clicking the menu bar icon shows the popover with an arrow pointing at the icon, and clicking the icon again closes it.
- [ ] Clicking outside the popover or pressing Esc closes it.
- [ ] Typing in the code box works immediately after opening, and ⌘↵ runs.
- [ ] "Open in window", "Settings…" and "Quit" work and close the popover first.
- [ ] The update banner still appears in the popover when an update is available.
- [ ] The arrow and the popover body match in light and dark appearance.
- [ ] No Dock icon appears while only the popover is used.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- No new automated tests: this is system UI. Manual: the checks above, listed in the PR.

## Risks and open questions
- A menu bar item's popover is attached to the screen's top edge. On a Mac with a notch or a crowded menu bar, the system may hide the icon. That is the same as today.
- The system material means the page-grey background from the mock is not drawn behind the header. The cards and footer keep their colours.
