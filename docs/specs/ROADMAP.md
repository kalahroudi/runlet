# Roadmap

Each line is one spec and one PR. Build in order. Specs 001 to 007 give a working Python playground. Agent features start at 010.

| # | Spec | Delivers | Depends on |
|---|------|----------|------------|
| 001 | [App shell](001-app-shell.md) (done) | Menu bar app that launches, shows a popover, opens a window and settings. CI builds it. | none |
| 002 | Runner core | Run a Python string as a child process. Stream output, enforce a time limit, report exit status. | 001 |
| 003 | Managed Python | Download and cache `uv` and Python 3.13. Create a fresh environment per snippet. | 002 |
| 004 | [Snippet store](004-snippet-store.md) (done) | Save snippets as files on disk with metadata. List, open, rename, delete. | 001 |
| 005 | [Editor and console](005-editor-console.md) (draft) | Window with a web-view editor (CodeMirror), Run button, console output. Scrolling areas hide the system scrollbar and use a styled, minimal scroll affordance (editor, console). | 002, 004 |
| 006 | [Quick run popover](006-quick-run-popover.md) (in progress) | Paste into the menu bar popover, detect language, run, see output. | 002, 004 |
| 007 | Missing packages (Python) | Detect imports, show the install bar, install on confirm, warn on unfamiliar names. | 003, 005 |
| 008 | Sandbox | Run snippets with network and file access off. Per-snippet toggles. | 002 |
| 009 | Preview pane and inputs | HTML or SVG preview in a web view. Sliders for numbers found in code. | 005 |
| 010 | MCP server | Local MCP tools: create_snippet, run, install_package, read_output. | 005, 008 |
| 011 | Magic link | `runlet://open/<id>` opens a snippet with its preview. Add an `open` MCP tool. | 009, 010 |
| 012 | Claude Code (headless) | Run Claude Code as a background process wired to the MCP server. Agents card in settings. | 010 |
| 013 | ACP bridge | ACP client so Codex, Gemini CLI and other agents connect. | 010 |
| 014 | Version history | Save a version per run or agent edit. Diff and restore. Agent attribution. | 004 |
| 015 | Capture | Global shortcut, grab selected text or a screen region, send to a connected agent. | 012 or 013 |
| 016 | JavaScript and TypeScript | Managed Bun runtime, same install bar for npm packages. | 003, 007 |
| 017 | Go and Rust | Managed toolchains. Compiler errors shown plainly. | 016 |
| 018 | Share | Link, preview card, network buttons, optional Gist. | 009, 014 |
| 019 | Spotlight and Shortcuts | Search snippets, run from Shortcuts. | 004, 002 |
| 020 | [Update from the app](020-self-update.md)  | "Update RunLet" in the popover: fetch latest main, rebuild, relaunch. Source installs only. | 001 |
| 021 | Signed downloads and updates | Developer ID signing, notarization, release builds and in-app updates (Sparkle) for people who do not build from source. | 020 |
| 022 | [Visual style](022-visual-style.md) (done) | Design kit from the mock (colours, fonts, buttons, cards) applied to the popover, main window and Settings. | 001 |
| 023 | [Native popover](023-native-popover.md) | Menu bar icon with a native popover anchored by an arrow, replacing the plain floating panel. | 001, 022 |
| 024 | [Interactive input](024-run-input.md) (done) | Type answers to `input()` while a run is in progress. | 002, 006 |
| 025 | [Run time limit](025-run-time-limit.md) (done) | Choose the run time limit in Settings (default 60 s, or none). Waiting for typed input does not count. | 002, 006, 024 |

Specs after 001 are written one at a time, just before they are built, so they reflect what the earlier PRs actually delivered.
