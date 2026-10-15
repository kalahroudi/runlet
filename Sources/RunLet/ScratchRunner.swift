import Foundation
import RunLetCore

struct OutputChunk: Identifiable {
    let id = UUID()
    var text: String
    var isError: Bool
}

/// Temporary scratch box for trying the runner by hand. Replaced by the editor and quick-run specs.
@MainActor
final class ScratchRunner: ObservableObject {
    static let timeLimit: TimeInterval = 10
    private static let outputLimit = 100_000

    @Published var source = #"print("Hello from RunLet")"#
    @Published private(set) var chunks: [OutputChunk] = []
    @Published private(set) var status = ""
    @Published private(set) var isRunning = false

    private let interpreter = PythonRunner.findInterpreter()
    private var task: Task<Void, Never>?
    private var shown = 0

    var pythonMissing: Bool { interpreter == nil }

    func run() {
        guard let interpreter, !isRunning else { return }
        chunks = []; shown = 0; status = ""; isRunning = true
        let source = source
        task = Task {
            for await event in PythonRunner.run(source: source, interpreter: interpreter, timeout: Self.timeLimit) {
                handle(event)
            }
            if Task.isCancelled { status = "Stopped" }
            isRunning = false
        }
    }

    func stop() { task?.cancel() }

    private func handle(_ event: RunEvent) {
        switch event {
        case .output(let stream, let text):
            append(text, isError: stream == .stderr)
        case .finished(let result):
            status = result.summary(timeLimit: Self.timeLimit)
        }
    }

    private func append(_ text: String, isError: Bool) {
        guard shown < Self.outputLimit else { return }
        let room = Self.outputLimit - shown
        let piece = String(text.prefix(room))
        shown += piece.count
        if let last = chunks.last, last.isError == isError {
            chunks[chunks.count - 1].text += piece
        } else {
            chunks.append(OutputChunk(text: piece, isError: isError))
        }
        if shown >= Self.outputLimit {
            chunks.append(OutputChunk(text: "\n… output truncated", isError: false))
        }
    }
}
