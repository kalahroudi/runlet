import SwiftUI

struct ScratchRunView: View {
    @StateObject private var runner = ScratchRunner()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Try it").font(.headline)
                Text("Python · temporary").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if runner.isRunning {
                    Button("Stop", action: runner.stop)
                } else {
                    Button("Run", action: runner.run)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(runner.pythonMissing)
                }
            }

            TextEditor(text: $runner.source)
                .font(.system(.body, design: .monospaced))
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            if runner.pythonMissing {
                Text("Python 3 was not found. Install it with `brew install python`. RunLet will manage Python for you in a later update.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    outputText
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 110)
                Text(runner.isRunning ? "Running…" : runner.status)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var outputText: Text {
        runner.chunks.reduce(Text("")) { text, chunk in
            text + Text(chunk.text).foregroundColor(chunk.isError ? .red : .primary)
        }
    }
}
