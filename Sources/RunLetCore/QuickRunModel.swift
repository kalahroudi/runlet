import Combine
import Foundation

public struct OutputChunk: Identifiable, Sendable {
    public let id = UUID()
    public var text: String
    public var isError: Bool
}

/// State of the quick run popover: the code box, the snippet it belongs to, the output of the last run.
@MainActor
public final class QuickRunModel: ObservableObject {
    private static let outputLimit = 100_000
    /// Starts a run of the source with the given time limit in seconds (`nil` = no limit).
    public typealias Runner = @Sendable (String, TimeInterval?) -> RunSession

    @Published public var source = "" {
        didSet {
            if source.isEmpty { currentID = nil }
            if source != oldValue { pasteNotice = nil }
        }
    }
    /// "Cleaned pasted code: … ⌘Z to undo." after a paste that was cleaned. Cleared by the next edit.
    @Published public private(set) var pasteNotice: String?
    @Published public private(set) var chunks: [OutputChunk] = []
    @Published public private(set) var status = ""
    @Published public private(set) var isRunning = false
    @Published public private(set) var recent: [Snippet] = []
    /// Every snippet, newest first. The main window's list.
    @Published public private(set) var all: [Snippet] = []
    @Published public private(set) var currentID: String?

    public let pythonAvailable: Bool
    private let store: SnippetStore
    private let runner: Runner
    private let timeLimit: () -> TimeInterval?
    private var limitUsed: TimeInterval?
    private var task: Task<Void, Never>?
    private var shown = 0
    private var session: RunSession?
    /// The text as last loaded or saved, so autosave can tell real edits from loading a snippet.
    private var savedSource = ""
    /// Bumped when the box switches to another snippet, so a run that was stopped cannot write into the new one.
    private var generation = 0

    public init(store: SnippetStore, pythonAvailable: Bool, timeLimit: @escaping () -> TimeInterval? = { 60 },
                runner: @escaping Runner) {
        self.timeLimit = timeLimit
        self.store = store
        self.pythonAvailable = pythonAvailable
        self.runner = runner
        refreshRecent()
    }

    /// Shows the notice for a paste. Called after the pasted text is in `source`, because changing `source` clears it.
    public func showPasteNotice(_ notice: String?) { pasteNotice = notice }

    public var detected: Language? { LanguageDetector.detect(source) }

    /// Anything that is not recognised is assumed to be Python.
    public var canRun: Bool {
        pythonAvailable && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (detected ?? .python) == .python
    }

    /// True when the box holds text that is not on disk yet.
    public var isDirty: Bool { source != savedSource }

    public func startRun() {
        guard canRun, !isRunning else { return }
        isRunning = true
        task = Task { await performRun() }
    }

    public func stop() { task?.cancel() }

    /// Saves the box as a snippet (new or updated), then runs it.
    public func performRun() async {
        let mine = generation
        isRunning = true
        chunks = []; shown = 0; status = ""
        do {
            try saveCurrent(force: true)
        } catch {
            status = "Could not save: \(error.localizedDescription)"
            isRunning = false
            return
        }
        limitUsed = timeLimit()
        let current = runner(CodeCleaner.clean(source, mode: .run).text, limitUsed)
        session = current
        for await event in current.events where mine == generation { handle(event) }
        guard mine == generation else { return }
        session = nil
        if Task.isCancelled { status = "Stopped" }
        isRunning = false
    }

    /// Writes the box to its snippet, creating one on the first non-empty save. Does nothing when there is
    /// nothing new to write, unless `force` is set. Used by Run and by the window's autosave.
    public func saveCurrent(force: Bool = false) throws {
        if let id = currentID {
            guard force || isDirty else { return }
            _ = try store.save(source: source, for: id)
        } else {
            guard !source.isEmpty else { return }
            currentID = try store.create(source: source).id
        }
        savedSource = source
        refreshRecent()
    }

    /// Types a line to the running program and shows it in the output like a terminal would.
    public func sendInput(_ line: String) {
        guard isRunning, let session else { return }
        session.send(line + "\n")
        append(line + "\n", isError: false)
    }

    /// Ends input, like Ctrl-D.
    public func endInput() { session?.closeInput() }

    public func newSnippet() {
        guard !isRunning else { return }
        clearBox()
    }

    public func load(_ snippet: Snippet) {
        guard !isRunning else { return }
        open(snippet)
    }

    /// Opens a snippet in the box. A run in progress is stopped first, because its output belongs to the old one.
    public func select(_ snippet: Snippet) {
        stopForSwitch()
        open(snippet)
    }

    /// Starts an empty snippet. A run in progress is stopped first.
    public func startNew() {
        stopForSwitch()
        clearBox()
    }

    /// Deletes a snippet. If it is the open one, the box is cleared.
    public func delete(_ snippet: Snippet) {
        if snippet.id == currentID { stopForSwitch(); clearBox() }
        try? store.delete(snippet.id)
        refreshRecent()
    }

    private func stopForSwitch() {
        task?.cancel()
        generation += 1
        session = nil
        isRunning = false
    }

    private func open(_ snippet: Snippet) {
        guard let text = try? store.source(of: snippet.id) else { return }
        source = text
        currentID = snippet.id
        savedSource = text
        chunks = []; status = ""; shown = 0
    }

    private func clearBox() {
        source = ""
        savedSource = ""
        chunks = []; status = ""; shown = 0
    }

    private func refreshRecent() {
        all = store.list()
        recent = Array(all.prefix(4))
    }

    private func handle(_ event: RunEvent) {
        switch event {
        case .output(let stream, let text): append(text, isError: stream == .stderr)
        case .finished(let result): status = result.summary(timeLimit: limitUsed)
        }
    }

    private func append(_ text: String, isError: Bool) {
        guard shown < Self.outputLimit else { return }
        let piece = String(text.prefix(Self.outputLimit - shown))
        shown += piece.count
        if let last = chunks.last, last.isError == isError {
            chunks[chunks.count - 1].text += piece
        } else {
            chunks.append(OutputChunk(text: piece, isError: isError))
        }
        if shown >= Self.outputLimit { chunks.append(OutputChunk(text: "\n… output truncated", isError: false)) }
    }
}
