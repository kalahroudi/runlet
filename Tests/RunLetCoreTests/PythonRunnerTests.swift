import Foundation
import Testing
@testable import RunLetCore

private let interpreter = PythonRunner.findInterpreter()

@Suite(.enabled(if: interpreter != nil, "Python 3 not found")) struct PythonRunnerTests {
    @Test func printsOutput() async {
        let out = await collect(PythonRunner.run(source: "print('hi')", interpreter: interpreter!))
        #expect(out.stdout == "hi\n")
        #expect(out.result?.exitCode == 0)
    }

    @Test func reportsATraceback() async {
        let out = await collect(PythonRunner.run(source: "raise ValueError('nope')", interpreter: interpreter!))
        #expect(out.stderr.contains("ValueError: nope"))
        #expect(out.result?.exitCode == 1)
    }

    @Test func removesItsTemporaryFolder() async {
        let out = await collect(PythonRunner.run(source: "import os; print(os.getcwd())", interpreter: interpreter!))
        let folder = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!folder.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder))
    }
}
