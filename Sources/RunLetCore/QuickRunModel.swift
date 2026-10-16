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
    nonisolated public static let timeLimit: TimeInterval = 10
    private static let outputLimit = 100_000
    public typealias Runner = @Sendable (String) -> AsyncStream<RunEvent>

    @Published public var source = "" {
        didSet { if source.isEmpty { currentID = nil } }
    }
    @Published public private(set) var chunks: [OutputChunk] = []
    @Published public private(set) var status = ""
    @Published public private(set) var isRunning = false
    @Published public private(set) var recent: [Snippet] = []
    @Published public private(set) var currentID: String?

    public let pythonAvailable: Bool
    private let store: SnippetStore
    private let runner: Runner
    private var task: Task<Void, Never>?
    private var shown = 0

    public init(store: SnippetStore, pythonAvailable: Bool, runner: @escaping Runner) {
        self.store = store
        self.pythonAvailable = pythonAvailable
        self.runner = runner
        refreshRecent()
    }

    public var detected: Language? { LanguageDetector.detect(source) }

    /// Anything that is not recognised is assumed to be Python.
    public var canRun: Bool {
        pythonAvailable && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (detected ?? .python) == .python
    }

    public func startRun() {
        guard canRun, !isRunning else { return }
        isRunning = true
        task = Task { await performRun() }
    }

    public func stop() { task?.cancel() }

    /// Saves the box as a snippet (new or updated), then runs it.
    public func performRun() async {
        isRunning = true
        chunks = []; shown = 0; status = ""
        do {
            if let id = currentID {
                _ = try store.save(source: source, for: id)
            } else {
                currentID = try store.create(source: source).id
            }
            refreshRecent()
        } catch {
            status = "Could not save: \(error.localizedDescription)"
            isRunning = false
            return
        }
        for await event in runner(source) { handle(event) }
        if Task.isCancelled { status = "Stopped" }
        isRunning = false
    }

    public func newSnippet() {
        guard !isRunning else { return }
        source = ""; chunks = []; status = ""; shown = 0
    }

    public func load(_ snippet: Snippet) {
        guard !isRunning, let text = try? store.source(of: snippet.id) else { return }
        source = text
        currentID = snippet.id
        chunks = []; status = ""; shown = 0
    }

    private func refreshRecent() { recent = Array(store.list().prefix(4)) }

    private func handle(_ event: RunEvent) {
        switch event {
        case .output(let stream, let text): append(text, isError: stream == .stderr)
        case .finished(let result): status = result.summary(timeLimit: Self.timeLimit)
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
