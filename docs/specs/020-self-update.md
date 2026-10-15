# Spec 020: Update from the app

Status: In progress
Depends on: 001
Size estimate: S (about 150 lines including tests)

## Why
Today the only way to update RunLet is to open a terminal in the repo and run `./scripts/install.sh`. After this spec, the menu bar popover has an "Update RunLet" item that fetches the latest `main`, rebuilds and relaunches the app, and says what it is doing.

## Scope
- A source-based updater for people who installed from this repo with `scripts/install.sh`. The app remembers the repo folder at install time.
- An "Update RunLet" item in the popover and a "Check for updates" row in Settings > General showing the current commit and whether `main` has newer commits.
- Progress and errors shown in plain words.

## Non-goals
- Signed releases, notarization, Sparkle or any download of prebuilt apps. That needs a Developer ID and a release pipeline, and gets its own spec.
- Automatic background updates. The update only happens when the person asks.
- Updating to a branch other than `main`, or when the repo has local changes.

## Behavior
- `scripts/install.sh` writes `~/Library/Application Support/RunLet/install.json` with the repo path and the commit built (`{"repo": "...", "commit": "..."}`), and the build embeds the same commit in `Info.plist` as `RunLetCommit`.
- Check: runs `git fetch origin main` in the repo, then compares `origin/main` with the installed commit. Shown as "Up to date" or "N new changes".
- Update: refuses with a clear message when the repo has uncommitted changes or is not on `main`, or when `install.json` is missing ("RunLet was not installed from source. Re-run scripts/install.sh once."). Otherwise it fast-forwards `main`, runs `scripts/install.sh` in a detached helper process, and the app quits so the helper can replace and relaunch it. If the build fails, the old app is left in place and the error is shown on the next launch.
- Uses `ProcessRunner` from spec 002 for git and the build, so output is streamed to an "Update" log with a Stop button.

## Acceptance criteria
- [x] After `scripts/install.sh`, `install.json` exists and the commit in it matches `git rev-parse HEAD`.
- [ ] With a newer commit on `origin/main`, Check shows "1 new change"; with none, "Up to date".
- [ ] Update with newer commits pulls, rebuilds and relaunches the app, and Settings shows the new commit.
- [ ] Update refuses, without changing anything, when the repo has local changes or is on another branch.
- [ ] A failing build leaves the old app installed and shows the error.
- [ ] Missing `install.json` shows the re-install message.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for the decision logic (up to date, behind, dirty repo, wrong branch, missing file) with git replaced by a stub.
- Manual: the update, refuse and failing-build cases above, listed in the PR.

## Risks and open questions
- The app replaces itself, so the helper must outlive the app. Use `nohup` from the script and verify it survives the quit.
- The repo path can move or be deleted. The error message must say so.
- Product decision (approved by the product owner): source install only for now. Signed downloadable updates are spec 021.
- The app stays running during the build and is replaced only by the last steps of `scripts/install.sh`, so a failed build leaves it in place. The relaunch step is the one that must be tried by hand.
