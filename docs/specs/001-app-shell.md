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
- A build that needs only the Xcode Command Line Tools, producing a signed-ad-hoc `RunLet.app`, plus a one-command install script.
- A CI workflow that builds and tests on every PR.
- App icon and a README with install steps for people and for agents.
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
- Structure: `Sources/RunLet` (the app), `Sources/RunLetCore` (logic that can be tested without a UI), `Tests/RunLetCoreTests`.
- Build tooling (changed from the first draft, which assumed Xcode and XcodeGen): a Swift package describes the targets for Xcode and CI. `scripts/build.sh` compiles with `swiftc` directly and assembles `build/RunLet.app`, so a Mac with only the Command Line Tools can build it. `scripts/install.sh` builds, copies to `/Applications` and opens the app.

## Acceptance criteria
- [ ] `./scripts/build.sh` succeeds on a Mac with the Command Line Tools and produces `build/RunLet.app`.
- [ ] Launching the app shows a menu bar icon and no Dock icon.
- [ ] The popover shows "RunLet", "Open in window", "Settings…" and "Quit". Quit exits the app.
- [ ] "Open in window" opens one window. Pressing it a second time does not create another.
- [ ] Settings opens with the General and Agents tabs.
- [ ] `swift test` passes. The tests assert that showing the window twice creates one window, and that showing it after it closed creates a new one.
- [ ] The CI workflow (`.github/workflows/ci.yml`) runs `swift test` and `./scripts/build.sh` on pull requests.
- [ ] The app has an icon (Dock and Finder).
- [ ] `README.md` starts with the icon and screenshots, then an agent section, then install steps for people.

## Test plan
- Unit test for the window coordinator.
- Manual: launch from Xcode, walk through the criteria above, note the result in the PR.

## Risks and open questions
- Bundle identifier is a placeholder (`com.runlet.app`). Confirm the real one before the signing spec.
- The window-style `MenuBarExtra` can behave oddly with focus. If it does, fall back to an `NSStatusItem` plus `NSPopover` in a later spec.
- The build is ad-hoc signed. Developer ID signing and notarization come in a later spec.

## Outcome notes
- The first draft assumed Xcode and XcodeGen. This Mac only has the Command Line Tools, and its SwiftPM is broken (the tool and its libraries are from different versions), so the build script uses `swiftc` directly. The Swift package stays for CI and Xcode users.
- Not verified locally: `swift test` (no working SwiftPM or test framework on this Mac), and clicking through the popover (no screen or accessibility access for automation). Both are covered by the CI run and the manual steps in the PR.
