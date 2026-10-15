# Spec 001: App shell

Status: Draft
Depends on: none
Size estimate: S (under 200 lines of hand-written code, plus project config)

## Why
Everything else needs a running app to live in. This spec produces a Mac app that sits in the menu bar, opens a popover and a window, and builds the same way locally and in CI. It does no code running yet.

## Scope
- A macOS app named RunLet, deployment target macOS 14.
- Menu bar item with a popover.
- A main window opened from the popover.
- A settings window.
- A project that builds from the command line, plus a CI workflow that does so on every PR.
- A test target with one real test.

## Non-goals
- Running any code, saving snippets, agents, capture, sharing.
- Final icon artwork. Use a placeholder SF Symbol for the menu bar and a plain app icon set.
- Code signing, notarization and Sparkle updates (a later spec).

## Behavior
- Launching the app shows a menu bar icon and no Dock icon (`LSUIElement`).
- Clicking the icon opens a popover (SwiftUI `MenuBarExtra` with the window style, about 380 pt wide). It shows the text "RunLet", a button "Open in window" and a button "Quit".
- "Open in window" opens one main window titled "RunLet" with placeholder content. Pressing it again brings the existing window to the front instead of opening a second one. While the window is open the app also appears in the Dock and the app switcher; closing it returns to menu-bar-only.
- ⌘, opens a Settings window with an "Agents" and a "General" tab, both showing placeholder text.
- Structure: `App/` (entry point and scenes), `Core/` (empty, for later specs), `Tests/`.
- The Xcode project is generated from `project.yml` with XcodeGen, and the generated `.xcodeproj` is not committed. This keeps diffs reviewable.

## Acceptance criteria
- [ ] `xcodegen generate && xcodebuild -scheme RunLet -destination 'platform=macOS' build` succeeds with no warnings treated as errors.
- [ ] Launching the built app shows a menu bar icon and no Dock icon.
- [ ] The popover shows "RunLet", "Open in window" and "Quit". Quit exits the app.
- [ ] "Open in window" opens one window. Pressing it a second time does not create another.
- [ ] ⌘, opens Settings with the Agents and General tabs.
- [ ] `xcodebuild test` passes. The one test asserts that opening the main window twice yields a single window (via a small window-coordinator type).
- [ ] The CI workflow (`.github/workflows/ci.yml`) runs the build and the tests on pull requests.
- [ ] `README.md` explains how to install XcodeGen, build and run.

## Test plan
- Unit test for the window coordinator.
- Manual: launch from Xcode, walk through the criteria above, note the result in the PR.

## Risks and open questions
- XcodeGen must be installed locally (`brew install xcodegen`). It is not installed on this Mac yet.
- Bundle identifier is a placeholder (`com.runlet.app`). Confirm the real one before the signing spec.
- The window-style `MenuBarExtra` can behave oddly with focus. If it does, fall back to an `NSStatusItem` plus `NSPopover` in this same PR and note it.
