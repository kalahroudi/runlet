import Foundation
import Testing
@testable import RunLetCore

struct SnippetStoreTests {
    let root: URL
    let store: SnippetStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("snips-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = SnippetStore(root: root, useTrash: false)
    }

    func folder(_ s: Snippet) -> URL { root.appendingPathComponent(s.id) }

    @Test func createWritesSourceAndMetadata() throws {
        let s = try store.create(title: "Hello", source: "print(1)")
        #expect(try String(contentsOf: folder(s).appendingPathComponent("main.py"), encoding: .utf8) == "print(1)")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: folder(s).appendingPathComponent("snippet.json"))) as? [String: Any]
        #expect(json?["title"] as? String == "Hello")
        #expect(json?["language"] as? String == "python")
        #expect(json?["created"] is String)
        #expect(store.list() == [s])
    }

    @Test func defaultTitleComesFromFirstLine() throws {
        #expect(try store.create(source: "\n\n  # hi there\nx = 1").title == "# hi there")
        #expect(try store.create(source: "   \n").title == "Untitled")
        #expect(try store.create(source: String(repeating: "a", count: 90)).title.count == 40)
    }

    @Test func sourceRoundTripsExactly() throws {
        let text = "print('héllo 🌍')\n# no newline at end"
        let s = try store.create(source: text)
        #expect(try store.source(of: s.id) == text)
    }

    @Test func saveChangesSourceAndModifiedOnly() throws {
        let s = try store.create(title: "T", source: "a")
        let saved = try store.save(source: "b", for: s.id)
        #expect(try store.source(of: s.id) == "b")
        #expect(saved.created == s.created && saved.title == "T")
        #expect(saved.modified >= s.modified)
    }

    @Test func renameChangesTitleOnly() throws {
        let s = try store.create(title: "Old", source: "keep me")
        let r = try store.rename(s.id, to: "New")
        #expect(r.title == "New")
        #expect(try store.source(of: s.id) == "keep me")
        #expect(store.list().first?.title == "New")
    }

    @Test func listIsNewestFirstAndIgnoresStrayFolders() throws {
        let a = try store.create(title: "a", source: "1")
        let b = try store.create(title: "b", source: "2")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("stray"), withIntermediateDirectories: true)
        // Make the order certain without sleeping.
        try Data(#"{"title":"a","language":"python","created":"2026-01-01T00:00:00Z","modified":"2026-01-02T00:00:00Z"}"#.utf8)
            .write(to: folder(a).appendingPathComponent("snippet.json"))
        #expect(store.list().map(\.id) == [b.id, a.id])
    }

    @Test func damagedMetadataStillListsAndOpens() throws {
        let missing = try store.create(title: "x", source: "one")
        let corrupt = try store.create(title: "y", source: "two")
        try FileManager.default.removeItem(at: folder(missing).appendingPathComponent("snippet.json"))
        try Data("not json".utf8).write(to: folder(corrupt).appendingPathComponent("snippet.json"))
        let listed = store.list()
        #expect(Set(listed.map(\.id)) == [missing.id, corrupt.id])
        #expect(listed.allSatisfy { $0.title == "Untitled" && $0.language == "python" })
        #expect(try store.source(of: corrupt.id) == "two")
        #expect(try store.save(source: "three", for: corrupt.id).title == "Untitled")
    }

    @Test func badIdsAreRejectedEverywhere() throws {
        for id in ["../x", "a/b", "..", ".", "", "missing"] {
            #expect(throws: SnippetError.notFound) { try store.source(of: id) }
            #expect(throws: SnippetError.notFound) { try store.save(source: "x", for: id) }
            #expect(throws: SnippetError.notFound) { try store.rename(id, to: "x") }
            #expect(throws: SnippetError.notFound) { try store.delete(id) }
        }
    }

    @Test func deleteRemovesTheSnippet() throws {
        let s = try store.create(source: "x")
        try store.delete(s.id)
        #expect(store.list().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder(s).path))
    }

    @Test func unknownMetadataFieldsSurviveSaves() throws {
        let s = try store.create(title: "t", source: "a")
        let file = folder(s).appendingPathComponent("snippet.json")
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        json["pinned"] = true
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        _ = try store.save(source: "b", for: s.id)
        _ = try store.rename(s.id, to: "u")
        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(after?["pinned"] as? Bool == true)
    }
}
