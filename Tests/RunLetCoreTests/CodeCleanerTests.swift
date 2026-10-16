import Foundation
import Testing
@testable import RunLetCore

struct CodeCleanerTests {
    private func paste(_ s: String) -> CleanResult { CodeCleaner.clean(s, mode: .paste) }
    private func run(_ s: String) -> CleanResult { CodeCleaner.clean(s, mode: .run) }

    @Test func leadingSpaceBlockIsDedented() {
        #expect(run(" for i in range(200): print(i)").text == "for i in range(200): print(i)")
        #expect(run(" for i in range(200): print(i)").changes == ["indent removed"])
    }

    @Test func sharedIndentKeepsRelativeIndent() {
        #expect(paste("    if x:\n        y()\n\n    z()").text == "if x:\n    y()\n\nz()")
    }

    @Test func firstLineLosingItsIndent() {
        #expect(paste("x = 1\n    y = 2\n    z = 3").text == "x = 1\ny = 2\nz = 3")
    }

    @Test func blockOpenerWithIndentedBodyIsLeftAlone() {
        let s = "for i in range(3):\n    print(i)"
        #expect(paste(s).text == s)
    }

    @Test func fences() {
        #expect(paste("```python\nprint(1)\n```").text == "print(1)")
        #expect(paste("```\nprint(1)\n```\n").text == "print(1)\n")
        #expect(paste("```py\nprint(1)").changes == ["markdown fence removed"])
    }

    @Test func promptTranscript() {
        let t = ">>> for i in range(2):\n...     print(i)\n...\n0\n1\n>>> x = 1"
        #expect(paste(t).text == "for i in range(2):\n    print(i)\n\nx = 1")
    }

    @Test func partialPromptsAreLeftAlone() {
        let s = "x = 1\n>>> y = 2\nz = 3\nw = 4"
        #expect(paste(s).text == s)
    }

    @Test func oddCharacters() {
        #expect(run("\u{FEFF}x\u{200B} =\u{00A0}1").text == "x = 1")
        #expect(run("a = 1\r\nb = 2\r\n").text == "a = 1\nb = 2\n")
    }

    @Test func mixedTabsAndSpaces() {
        #expect(run("if x:\n\ty()\n    z()").text == "if x:\n    y()\n    z()")
    }

    @Test func consistentTabsUntouched() {
        let s = "if x:\n\ty()\n\tz()"
        #expect(run(s).changes.isEmpty)
        #expect(run(s).text == s)
    }

    @Test func curlyQuotesAsQuotes() {
        #expect(run("print(“hi”)").text == "print(\"hi\")")
        #expect(run("print(‘hi’)").text == "print('hi')")
    }

    @Test func curlyQuotesInsideStringsAndCommentsStay() {
        let s = "print(\"it’s “fine”\")  # don’t touch “this”"
        #expect(run(s).text == s)
        #expect(run("x = '''a “b” c'''").changes.isEmpty)
    }

    @Test func cleanTextIsUnchanged() {
        let s = "import os\n\ndef f():\n    return os.getcwd()\n"
        #expect(paste(s) == CleanResult(text: s, changes: []))
        #expect(paste(s).notice(for: .paste) == nil)
    }

    @Test func cleaningTwiceChangesNothingMore() {
        for s in ["```python\n    a = 1\n    b = “x”\n```", ">>> a = 1\n1", "\u{FEFF} x = 1\r\n"] {
            let once = paste(s).text
            #expect(paste(once).text == once)
        }
    }

    @Test func runModeKeepsLineCount() {
        let s = "```python\n    a = 1\n    b = 2\n```"
        #expect(run(s).text.components(separatedBy: "\n").count == 4)
        #expect(paste(s).text.components(separatedBy: "\n").count == 2)
    }

    @Test func notices() {
        #expect(run(" x = 1").notice(for: .run) == "Ran with indent removed.")
        #expect(paste("```\n x = 1\n```").notice(for: .paste) == "Cleaned pasted code: markdown fence removed, indent removed. ⌘Z to undo.")
    }
}

@MainActor
struct RunCleaningTests {
    @Test func runSendsCleanedCopyAndLeavesBoxAlone() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        final class Seen: @unchecked Sendable { var text = "" }
        let seen = Seen()
        let model = QuickRunModel(store: SnippetStore(root: dir, useTrash: false), pythonAvailable: true) { source, _ in
            seen.text = source
            return RunSession(events: AsyncStream { $0.finish() })
        }
        model.source = " print(1)"
        await model.performRun()
        #expect(seen.text == "print(1)")
        #expect(model.source == " print(1)")
    }
}
