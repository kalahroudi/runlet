import SwiftUI

struct ScratchRunView: View {
    @StateObject private var runner = ScratchRunner()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RLSectionTitle("Try it")
                RLChip(text: "Python")
                Spacer()
                if runner.isRunning {
                    Button("Stop", action: runner.stop).buttonStyle(.rlSmall)
                } else {
                    Button("▶ Run", action: runner.run)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.rlSmallPrimary)
                        .disabled(runner.pythonMissing)
                }
            }

            TextEditor(text: $runner.source)
                .font(RLFont.mono(12.5))
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(6)
                .frame(height: 110)
                .background(Color.rlCode, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rlLine))

            if runner.pythonMissing {
                Text("Python 3 was not found. Install it with `brew install python`. RunLet will manage Python for you in a later update.")
                    .font(RLFont.body(13)).foregroundStyle(Color.rlMuted)
            } else {
                ScrollView {
                    outputText
                        .font(RLFont.mono(12.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .scrollIndicators(.hidden)
                .frame(height: 110)
                .background(Color.rlCode, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rlLine))
                RLStatusLine(text: runner.isRunning ? "Running…" : runner.status,
                             isOK: runner.status.hasPrefix("Finished"))
            }
        }
    }

    private var outputText: Text {
        runner.chunks.reduce(Text("")) { text, chunk in
            text + Text(chunk.text).foregroundColor(chunk.isError ? .red : Color.rlInk)
        }
    }
}
