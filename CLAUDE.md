# RunLet

A Mac menu bar and windowed playground for running code snippets, with agents (Claude Code headless, others over ACP) that can write, run and visualise code through a local MCP server.

## How we work
- Spec-driven: one spec in `docs/specs/`, one PR. Read `docs/specs/README.md` first.
- Do not start a spec until its status is `Approved`. Do not widen a spec while building it; propose a new one.
- Keep PRs under about 500 changed lines.
- Update the spec's status and tick its criteria in the same PR that implements it.
- The visual mock in `docs/mock/runlet.html` shows the intended look and flow. It is scripted and not a source of truth for behavior.

## Stack
Swift and SwiftUI for the app (macOS 14+), a CodeMirror editor in a WKWebView, managed runtimes (uv for Python, Bun for JS and TS). Xcode project generated with XcodeGen.

## Shortcuts
Capture is ⌃⌥C. Do not use ⌘⇧R (browser hard refresh).
