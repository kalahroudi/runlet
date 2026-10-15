# Spec 004: Snippet store

Status: In progress
Depends on: 001
Size estimate: M (about 300 lines including tests)

## Why
Code needs a home. After this spec, snippets are saved as plain files on disk, survive quitting the app, and can be listed, opened, renamed and deleted by the code that later specs add (editor, popover, agents, Spotlight). There is no UI here.

## Scope
- `SnippetStore` in `RunLetCore`: create, read, update source, rename, delete, list.
- On-disk format that a person or an agent can read and edit with ordinary tools.
- Safe writes and tolerance of damaged or hand-edited files.

## Non-goals
- Any UI (specs 005 and 006 add it).
- Languages other than Python. The metadata has a `language` field so later specs can add more.
- Search, tags, folders, sync, import and export.
- Watching the folder for outside changes. The list is read when asked for.
- Version history.

## Behavior
### Layout on disk
Root: `~/Library/Application Support/RunLet/Snippets/`, one folder per snippet named by its id (a lowercase UUID):
```
<id>/main.py        the source, exactly as typed
<id>/snippet.json   {"title": "...", "language": "python", "created": "<ISO 8601>", "modified": "<ISO 8601>"}
```
The store takes its root as a parameter so tests use a temporary folder.

### Interface
```swift
public struct Snippet: Equatable, Identifiable { id: String; title: String; language: String; created: Date; modified: Date }
public final class SnippetStore {
  init(root: URL)
  func create(title: String?, source: String) throws -> Snippet
  func source(of id: String) throws -> String
  func save(source: String, for id: String) throws -> Snippet   // updates modified
  func rename(_ id: String, to title: String) throws -> Snippet
  func delete(_ id: String) throws
  func list() -> [Snippet]                                       // newest modified first
}
```
- `create` with no title uses the first non-empty line of the source, trimmed to 40 characters, or "Untitled" when there is none.
- Writes are atomic (write to a temporary file, then replace), so a crash never leaves a half-written file.
- `list` skips folders that have no `main.py`. If `snippet.json` is missing or unreadable, the snippet still appears with title "Untitled", language "python" and the file dates, and the file is rewritten on the next save.
- Ids come only from the store. Any id that is not a known folder name inside the root (for example one containing `/` or `..`) is rejected with `SnippetError.notFound`, so callers cannot reach files outside the root.
- `delete` moves the folder to the Trash, so a mistake can be undone from Finder. If the Trash is unavailable it removes the folder.
- Unknown extra fields in `snippet.json` are kept when the file is rewritten.

## Acceptance criteria
- [x] Creating a snippet makes `<id>/main.py` with the exact source and a valid `snippet.json`.
- [x] `source(of:)` returns exactly what was saved, including non-ASCII text and a missing trailing newline.
- [x] `save` changes the source and `modified` but not `created` or the title.
- [x] `rename` changes the title and nothing else in the source.
- [x] `list` returns snippets newest modified first, and a stray folder without `main.py` is ignored.
- [x] A snippet with a deleted or corrupt `snippet.json` is still listed and still opens.
- [x] Ids such as `../x` or `a/b` are rejected for every method.
- [x] `delete` removes the snippet from `list` and from the root folder.
- [x] Unknown fields in `snippet.json` survive a save.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests in `RunLetCoreTests` using a temporary root for every case above. Deletion tests use the removal fallback, since the Trash is not predictable in CI.
- Manual: none, there is no UI. Spec 005 exercises it end to end.

## Risks and open questions
- Moving to the Trash behaves differently in a sandboxed app. RunLet is not sandboxed yet; revisit with spec 008.
- Date round trips lose sub-second precision in ISO 8601. Tests compare to the second.
- Spec 005 uses placeholder store method names. Once this spec is approved, update 005 to match the interface above.
