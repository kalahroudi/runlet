import Foundation

public struct Snippet: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var language: String
    public var created: Date
    public var modified: Date
}

public enum SnippetError: Error, Equatable {
    case notFound
}

/// Snippets as plain files: `<root>/<id>/main.py` and `<root>/<id>/snippet.json`.
public final class SnippetStore {
    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RunLet/Snippets")
    }

    private let root: URL
    private let useTrash: Bool
    private let fm = FileManager.default

    /// `useTrash: false` removes deleted snippets outright, which tests use because the Trash is not predictable.
    public init(root: URL = SnippetStore.defaultRoot, useTrash: Bool = true) {
        self.root = root
        self.useTrash = useTrash
    }

    public func create(title: String? = nil, source: String) throws -> Snippet {
        let id = UUID().uuidString.lowercased()
        let folder = root.appendingPathComponent(id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try write(source, to: folder.appendingPathComponent("main.py"))
        let now = Self.whole(Date())
        let snippet = Snippet(id: id, title: title ?? Self.defaultTitle(for: source), language: "python",
                              created: now, modified: now)
        try writeMeta(snippet, extra: [:])
        return snippet
    }

    public func source(of id: String) throws -> String {
        let data = try Data(contentsOf: mainFile(id))
        return String(decoding: data, as: UTF8.self)
    }

    public func save(source: String, for id: String) throws -> Snippet {
        let file = try mainFile(id)
        let (current, extra) = try readMeta(id)
        try write(source, to: file)
        var updated = current
        updated.modified = Self.whole(Date())
        try writeMeta(updated, extra: extra)
        return updated
    }

    public func rename(_ id: String, to title: String) throws -> Snippet {
        _ = try mainFile(id)
        var (snippet, extra) = try readMeta(id)
        snippet.title = title
        try writeMeta(snippet, extra: extra)
        return snippet
    }

    public func delete(_ id: String) throws {
        let folder = try folder(id)
        if useTrash, (try? fm.trashItem(at: folder, resultingItemURL: nil)) != nil { return }
        try fm.removeItem(at: folder)
    }

    /// Newest modified first. Folders without a `main.py` are ignored.
    public func list() -> [Snippet] {
        let names = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        return names.compactMap { try? readMeta($0).0 }.sorted { $0.modified > $1.modified }
    }

    // MARK: - Files

    /// Only a plain folder name inside the root is an id, so callers cannot reach other paths.
    private func folder(_ id: String) throws -> URL {
        guard !id.isEmpty, id != ".", id != "..", !id.contains("/"), !id.contains("\0") else { throw SnippetError.notFound }
        let url = root.appendingPathComponent(id)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { throw SnippetError.notFound }
        return url
    }

    private func mainFile(_ id: String) throws -> URL {
        let file = try folder(id).appendingPathComponent("main.py")
        guard fm.fileExists(atPath: file.path) else { throw SnippetError.notFound }
        return file
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private func readMeta(_ id: String) throws -> (Snippet, [String: Any]) {
        let main = try mainFile(id)
        let attributes = try? fm.attributesOfItem(atPath: main.path)
        let fileCreated = (attributes?[.creationDate] as? Date) ?? Date()
        let fileModified = (attributes?[.modificationDate] as? Date) ?? fileCreated
        let json = (try? Data(contentsOf: main.deletingLastPathComponent().appendingPathComponent("snippet.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let snippet = Snippet(
            id: id,
            title: json["title"] as? String ?? "Untitled",
            language: json["language"] as? String ?? "python",
            created: Self.date(json["created"]) ?? Self.whole(fileCreated),
            modified: Self.date(json["modified"]) ?? Self.whole(fileModified))
        var extra = json
        for key in ["title", "language", "created", "modified"] { extra[key] = nil }
        return (snippet, extra)
    }

    private func writeMeta(_ snippet: Snippet, extra: [String: Any]) throws {
        var json = extra
        json["title"] = snippet.title
        json["language"] = snippet.language
        json["created"] = Self.iso.string(from: snippet.created)
        json["modified"] = Self.iso.string(from: snippet.modified)
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent(snippet.id).appendingPathComponent("snippet.json"), options: .atomic)
    }

    // MARK: - Helpers

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func date(_ value: Any?) -> Date? {
        (value as? String).flatMap { iso.date(from: $0) }
    }

    /// Dates are stored to the second, so drop the rest to keep what is returned equal to what is read back.
    private static func whole(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    static func defaultTitle(for source: String) -> String {
        let line = source.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return "Untitled" }
        return String(line.prefix(40))
    }
}
