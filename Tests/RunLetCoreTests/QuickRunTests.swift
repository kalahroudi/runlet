import Foundation
import Testing
@testable import RunLetCore

@Suite struct LanguageDetectorTests {
    @Test func detectsEachLanguage() {
        #expect(LanguageDetector.detect("package main\nfunc main() {\n}") == .go)
        #expect(LanguageDetector.detect("fn main() {\n  println!(\"hi\");\n}") == .rust)
        #expect(LanguageDetector.detect("let mut total = 0;") == .rust)
        #expect(LanguageDetector.detect("interface User { name: string }") == .typescript)
        #expect(LanguageDetector.detect("const add = (a, b) => a + b") == .javascript)
        #expect(LanguageDetector.detect("def add(a, b):\n    return a + b") == .python)
        #expect(LanguageDetector.detect("import os\nprint(os.getcwd())") == .python)
    }

    @Test func earlierRulesWin() {
        #expect(LanguageDetector.detect("func f() { const x: number = 1 }") == .go)
        #expect(LanguageDetector.detect("const x: number = 1; console.log(x)") == .typescript)
    }

    @Test func shortOrUnrecognisedIsNil() {
        #expect(LanguageDetector.detect("print(1)") == nil)
        #expect(LanguageDetector.detect("   ") == nil)
        #expect(LanguageDetector.detect("just some words here") == nil)
    }
}

@Suite struct RelativeTimeTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    let now = Date(timeIntervalSince1970: 1_760_000_000) // 2025-10-09 08:53 UTC, a Thursday

    @Test func formatsRecentTimes() {
        #expect(RelativeTime.text(for: now.addingTimeInterval(-20), now: now, calendar: calendar) == "Just now")
        #expect(RelativeTime.text(for: now.addingTimeInterval(-300), now: now, calendar: calendar) == "5m ago")
        #expect(RelativeTime.text(for: now.addingTimeInterval(-7300), now: now, calendar: calendar) == "2h ago")
    }

    @Test func formatsOlderTimes() {
        #expect(RelativeTime.text(for: now.addingTimeInterval(-86_400), now: now, calendar: calendar) == "Yesterday")
        #expect(RelativeTime.text(for: now.addingTimeInterval(-3 * 86_400), now: now, calendar: calendar) == "Mon")
        #expect(RelativeTime.text(for: now.addingTimeInterval(-10 * 86_400), now: now, calendar: calendar) == "Sep 29")
    }
}

@MainActor
@Suite struct QuickRunModelTests {
    func makeModel(python: Bool = true) -> (QuickRunModel, SnippetStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("runlet-\(UUID().uuidString)")
        let store = SnippetStore(root: root, useTrash: false)
        let model = QuickRunModel(store: store, pythonAvailable: python) { _, _ in
            RunSession(events: AsyncStream { c in
                c.yield(.output(.stdout, "hi\n"))
                c.yield(.output(.stderr, "oops\n"))
                c.yield(.finished(RunResult(exitCode: 0, outcome: .exited, duration: 0.01)))
                c.finish()
            })
        }
        return (model, store)
    }

    @Test func firstRunCreatesASnippetAndSecondRunUpdatesIt() async throws {
        let (model, store) = makeModel()
        model.source = "print('one')  # first"
        await model.performRun()
        #expect(store.list().count == 1)
        #expect(model.chunks.map(\.isError) == [false, true])
        #expect(model.status == "Finished in 10 ms")

        model.source = "print('two')  # second"
        await model.performRun()
        let all = store.list()
        #expect(all.count == 1)
        #expect(try store.source(of: all[0].id) == "print('two')  # second")
    }

    @Test func loadingThenRunningUpdatesThatSnippet() async throws {
        let (model, store) = makeModel()
        let made = try store.create(source: "print('old')  # old")
        model.load(made)
        #expect(model.source == "print('old')  # old")
        model.source = "print('new')  # new"
        await model.performRun()
        #expect(store.list().count == 1)
        #expect(try store.source(of: made.id) == "print('new')  # new")
    }

    @Test func newClearsTheBoxAndNextRunCreatesAnotherSnippet() async {
        let (model, store) = makeModel()
        model.source = "print('a')  # a"
        await model.performRun()
        model.newSnippet()
        #expect(model.source.isEmpty && model.currentID == nil)
        model.source = "print('b')  # b"
        await model.performRun()
        #expect(store.list().count == 2)
        #expect(model.recent.count == 2)
    }

    @Test func otherLanguagesAndMissingPythonCannotRun() {
        let (model, _) = makeModel()
        model.source = "package main\nfunc main() {}"
        #expect(!model.canRun)
        model.source = "print('x')  # python"
        #expect(model.canRun)
        let (noPython, _) = makeModel(python: false)
        noPython.source = "print('x')  # python"
        #expect(!noPython.canRun)
    }

    @Test func recentKeepsTheFourNewest() throws {
        let (model, store) = makeModel()
        for i in 0..<6 { _ = try store.create(source: "print(\(i))  # n") }
        model.load(store.list()[0])
        #expect(store.list().count == 6)
        #expect(QuickRunModel(store: store, pythonAvailable: true) { _, _ in RunSession(events: AsyncStream { $0.finish() }) }.recent.count == 4)
    }

    @Test func autosaveCreatesOnFirstTextAndSkipsUnchangedText() throws {
        let (model, store) = makeModel()
        try model.saveCurrent()
        #expect(store.list().isEmpty)
        model.source = "print('a')  # a"
        #expect(model.isDirty)
        try model.saveCurrent()
        #expect(store.list().count == 1 && !model.isDirty)
        let stamp = store.list()[0].modified
        try model.saveCurrent()
        #expect(store.list()[0].modified == stamp)
        model.source = "print('b')  # b"
        try model.saveCurrent()
        #expect(store.list().count == 1)
        #expect(try store.source(of: model.currentID!) == "print('b')  # b")
    }

    @Test func openingASnippetIsNotAnEdit() throws {
        let (model, store) = makeModel()
        let made = try store.create(source: "print(1)  # one")
        model.select(made)
        #expect(!model.isDirty && model.currentID == made.id)
    }

    @Test func deletingTheOpenSnippetClearsTheBox() throws {
        let (model, store) = makeModel()
        let made = try store.create(source: "print(1)  # one")
        model.select(made)
        model.delete(made)
        #expect(model.source.isEmpty && model.currentID == nil && store.list().isEmpty && model.all.isEmpty)
    }

    @Test func switchingSnippetsStopsARunAndKeepsItsOutputOut() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("runlet-\(UUID().uuidString)")
        let store = SnippetStore(root: root, useTrash: false)
        let model = QuickRunModel(store: store, pythonAvailable: true) { _, _ in
            RunSession(events: AsyncStream { c in
                c.yield(.output(.stdout, "working\n"))
                // never finishes by itself
                c.onTermination = { _ in }
            })
        }
        let other = try store.create(source: "print(2)  # two")
        model.source = "print(1)  # one"
        model.startRun()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(model.isRunning)
        model.select(other)
        #expect(!model.isRunning)
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(model.chunks.isEmpty && model.status.isEmpty && model.source == "print(2)  # two")
    }
}
