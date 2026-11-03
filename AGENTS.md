# RunLet agent guide

RunLet is a Mac menu bar and windowed playground for running code snippets, with agents that can write, run and visualise code through a local MCP server. Read `CLAUDE.md` for the short version and `docs/specs/README.md` for the workflow. This file adds the rules an automated agent needs.

## Before you change anything

- Read `CLAUDE.md`, `docs/specs/README.md`, `docs/specs/ROADMAP.md`, the issue you were asked to deliver, and the relevant source.
- One spec, one PR. A spec is approved before code. Do not widen a spec; propose a new one.
- Keep a PR under about 500 changed lines, excluding generated files and lockfiles.
- The visual mock in `docs/mock/runlet.html` shows the intended look and flow. It is scripted and not a source of truth for behavior.

## If the issue asks for a spec

Deliver one spec-only PR.

- Branch `spec/NNN-short-name`; PR title `Spec NNN: Short name (draft)`.
- Copy `docs/specs/_template.md`, keep the status `Draft`, list dependencies and non-goals, and make every acceptance criterion observable.
- Do not write implementation code in this PR. Stop after the PR is open and ask the owner to review and merge it.

## If the issue asks to build an approved spec

- Build exactly the approved spec on `build/NNN-short-name`; PR title `Spec NNN: Short name`.
- Update the spec's status and tick its acceptance criteria in the same PR, and update its row in `docs/specs/ROADMAP.md`.
- Run `swift test` and `./scripts/build.sh`. If `editor/src` changes, rebuild the committed editor bundle with `scripts/build-editor.sh` and commit the result.
- UI cannot be verified from an offscreen harness. List the manual checks the owner must do in the PR body and do not claim them as verified.
- A person merges every PR. Never enable auto-merge and never push to `main`.
- Start every GitHub message with the automated-agent disclosure line.

## Queue and one-at-a-time rule

- The delivery queue is issue #51. Each linked issue is one roadmap item.
- The owner triggers an item with a comment. Do not start a second item while the previous item's PR is open and unmerged.
- The deployment runs at most one Executor (`maxWorkers: 1`), so tickets cannot run concurrently; trigger one at a time anyway.
- Spec 021 (signed downloads and updates) needs owner-supplied Apple Developer ID and notarization credentials. Do not trigger it until spec 020 is Done and the owner has supplied them.

## Useful commands

- `swift test` runs the 80+ Swift Testing tests.
- `./scripts/build.sh` builds `build/RunLet.app`.
- `scripts/build-editor.sh` rebuilds the committed CodeMirror bundle (needs Node).
- Do not use ⌘⇧R for anything; the Capture shortcut is ⌃⌥C.
