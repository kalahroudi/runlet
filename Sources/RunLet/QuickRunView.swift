import SwiftUI
import RunLetCore

extension QuickRunModel {
    static let shared: QuickRunModel = {
        let interpreter = PythonRunner.findInterpreter()
        return QuickRunModel(store: SnippetStore(), pythonAvailable: interpreter != nil) { source in
            guard let interpreter else { return AsyncStream { $0.finish() } }
            return PythonRunner.run(source: source, interpreter: interpreter, timeout: QuickRunModel.timeLimit)
        }
    }()
}

struct QuickRunView: View {
    @ObservedObject var model: QuickRunModel = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RLSectionTitle("Code")
                Spacer()
                if !model.source.isEmpty {
                    Button("New") { model.newSnippet() }.buttonStyle(.plain)
                        .font(RLFont.body(12, .semibold)).foregroundStyle(Color.rlAccent)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                codeBox
                if model.isRunning {
                    Button("Stop", action: model.stop).buttonStyle(.rlSmall)
                } else {
                    Button("▶ Run", action: model.startRun)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.rlSmallPrimary)
                        .disabled(!model.canRun)
                }
            }
            languageRow
            notice
            if model.pythonAvailable {
                if !model.chunks.isEmpty || model.isRunning || !model.status.isEmpty { output }
            }
            if !model.recent.isEmpty { recent }
        }
    }

    private var codeBox: some View {
        let lines = min(max(model.source.split(separator: "\n", omittingEmptySubsequences: false).count, 3), 8)
        return TextEditor(text: $model.source)
            .font(RLFont.mono(12.5))
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .padding(6)
            .frame(height: CGFloat(lines) * 17 + 14)
            .background(Color.rlCode, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rlLine))
            .overlay(alignment: .topLeading) {
                if model.source.isEmpty {
                    Text("Paste code here")
                        .font(RLFont.mono(12.5)).foregroundStyle(Color.rlMuted)
                        .padding(.horizontal, 11).padding(.vertical, 6).allowsHitTesting(false)
                }
            }
    }

    private var languageRow: some View {
        HStack(spacing: 6) {
            ForEach(Language.allCases, id: \.self) { language in
                RLChip(text: language == .python ? language.displayName : "\(language.displayName) · soon",
                       selected: model.detected == language)
                    .opacity(language == .python || model.detected == language ? 1 : 0.6)
            }
        }
        .font(RLFont.body(11))
    }

    @ViewBuilder private var notice: some View {
        if !model.pythonAvailable {
            Text("Python 3 was not found. Install it with `brew install python`. RunLet will manage Python for you in a later update.")
                .font(RLFont.body(12.5)).foregroundStyle(Color.rlMuted)
        } else if let language = model.detected {
            if language == .python {
                RLStatusLine(text: "Detected Python from what you pasted", isOK: true)
            } else {
                RLStatusLine(text: "Looks like \(language.displayName). Only Python runs for now.")
            }
        }
    }

    private var output: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.chunks.isEmpty {
                ScrollView {
                    outputText
                        .font(RLFont.mono(12.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .scrollIndicators(.hidden)
                .frame(height: 96)
                .background(Color.rlCode, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rlLine))
            }
            RLStatusLine(text: model.isRunning ? "Running…" : model.status,
                         isOK: model.status.hasPrefix("Finished"))
        }
    }

    private var outputText: Text {
        model.chunks.reduce(Text("")) { text, chunk in
            text + Text(chunk.text).foregroundColor(chunk.isError ? .red : Color.rlInk)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 4) {
            RLSectionTitle("Recent")
            ForEach(model.recent) { snippet in
                Button { model.load(snippet) } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Color.rlAccent).frame(width: 7, height: 7)
                        Text(snippet.title).font(RLFont.mono(12)).foregroundStyle(Color.rlInk).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(RelativeTime.text(for: snippet.modified))
                            .font(RLFont.body(11.5)).foregroundStyle(Color.rlMuted)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
