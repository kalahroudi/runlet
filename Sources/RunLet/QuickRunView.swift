import SwiftUI
import RunLetCore

extension QuickRunModel {
    static let shared: QuickRunModel = {
        let interpreter = PythonRunner.findInterpreter()
        return QuickRunModel(
            store: SnippetStore(), pythonAvailable: interpreter != nil,
            timeLimit: { TimeLimitChoice(stored: UserDefaults.standard.string(forKey: TimeLimitChoice.defaultsKey)).seconds }
        ) { source, limit in
            guard let interpreter else { return RunSession(events: AsyncStream { $0.finish() }) }
            return PythonRunner.start(source: source, interpreter: interpreter, timeout: limit, interactive: true)
        }
    }()
}

extension Language {
    var dotColor: Color {
        switch self {
        case .python: Color(red: 0.216, green: 0.463, blue: 0.671)
        case .javascript: Color(red: 0.941, green: 0.784, blue: 0.078)
        case .typescript: Color(red: 0.192, green: 0.471, blue: 0.776)
        case .go: Color(red: 0, green: 0.678, blue: 0.847)
        case .rust: Color(red: 0.871, green: 0.647, blue: 0.518)
        }
    }
}

/// The popover body from the mock: language chips and Run, a detection line, the code card, Recent.
struct QuickRunView: View {
    @ObservedObject var model: QuickRunModel = .shared

    private var shown: Language { model.detected ?? .python }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            notice
            codeCard
            if !model.recent.isEmpty { recent }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            RLChip(text: "Python", selected: shown == .python, dot: Language.python.dotColor)
            if shown != .python {
                RLChip(text: shown.displayName, selected: true, dot: shown.dotColor)
            }
            moreMenu
            Spacer(minLength: 8)
            if !model.source.isEmpty && !model.isRunning {
                Button { model.newSnippet() } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.rlIcon).help("New snippet")
            }
            if model.isRunning {
                Button("Stop", action: model.stop).buttonStyle(.rlSmall)
            } else {
                Button("▶ Run", action: model.startRun)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.rlSmallPrimary)
                    .disabled(!model.canRun)
            }
        }
    }

    /// Python is the default. Every other runtime lives behind this menu.
    private var moreMenu: some View {
        Menu {
            ForEach(Language.allCases.filter { $0 != .python && $0 != shown }, id: \.self) { language in
                Button("\(language.displayName) · soon") {}.disabled(true)
            }
            Divider()
            Button("Ruby, Swift, SQL and more later") {}.disabled(true)
        } label: {
            RLChip(text: "More ▾")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder private var notice: some View {
        if !model.pythonAvailable {
            Text("Python 3 was not found. Install it with `brew install python`. RunLet will manage Python for you in a later update.")
                .font(RLFont.body(12.5)).foregroundStyle(Color.rlMuted)
        } else if let language = model.detected {
            if language == .python {
                RLStatusLine(text: "✓ Detected Python from what you pasted", isOK: true)
            } else {
                RLStatusLine(text: "Looks like \(language.displayName). Only Python runs for now.")
            }
        }
    }

    // MARK: Code card

    private var codeCard: some View {
        VStack(spacing: 0) {
            codeBox
            ConsoleView(model: model, maxOutputHeight: 110)
        }
        .background(Color.rlCode, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rlLine))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var codeBox: some View {
        let lines = min(max(model.source.split(separator: "\n", omittingEmptySubsequences: false).count, 4), 9)
        return TextEditor(text: $model.source)
            .font(RLFont.mono(12.5))
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .padding(.horizontal, 7).padding(.vertical, 6)
            .frame(height: CGFloat(lines) * 19 + 12)
            .overlay(alignment: .topLeading) {
                if model.source.isEmpty {
                    Text("Paste code here…")
                        .font(RLFont.mono(12.5)).foregroundStyle(Color.rlMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6).allowsHitTesting(false)
                }
            }
    }

    // MARK: Recent

    private var recent: some View {
        VStack(alignment: .leading, spacing: 2) {
            RLSectionTitle("Recent").padding(.bottom, 2)
            ForEach(model.recent) { snippet in
                RecentRow(snippet: snippet) { model.load(snippet) }
            }
        }
    }
}

private struct RecentRow: View {
    let snippet: Snippet
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(Language.python.dotColor).frame(width: 8, height: 8)
                Text(snippet.title).font(RLFont.body(13, .medium)).foregroundStyle(Color.rlInk).lineLimit(1)
                Spacer(minLength: 8)
                Text(RelativeTime.text(for: snippet.modified))
                    .font(RLFont.body(12)).foregroundStyle(Color.rlMuted)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(hovering ? Color.rlSurface2 : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Where the person types answers while a program is running.
struct InputLine: View {
    @ObservedObject var model: QuickRunModel
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("›").font(RLFont.mono(13)).foregroundStyle(Color.rlAccent)
            TextField("Type input, press Return", text: $text)
                .textFieldStyle(.plain)
                .font(RLFont.mono(12.5))
                .focused($focused)
                .onSubmit { model.sendInput(text); text = "" }
            Button { model.endInput() } label: { Image(systemName: "arrow.down.to.line") }
                .buttonStyle(.rlIcon).help("End input (⌘D)")
                .keyboardShortcut("d", modifiers: .command)
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 2)
        .onAppear { focused = true }
    }
}

/// Output, the input line and the status of the run. Used in the popover card and in the window.
struct ConsoleView: View {
    @ObservedObject var model: QuickRunModel
    /// Popover: the output grows up to this height. Window: nil, the output fills the space.
    var maxOutputHeight: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            if !model.chunks.isEmpty || maxOutputHeight == nil {
                if maxOutputHeight != nil { divider }
                StyledScrollView(fade: Color.rlCode, followsEnd: true) {
                    outputText
                        .font(RLFont.mono(12.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .frame(maxHeight: maxOutputHeight ?? .infinity)
            }
            if model.isRunning {
                divider
                InputLine(model: model)
            }
            if model.isRunning || !model.status.isEmpty {
                divider
                let ok = model.status.hasPrefix("Finished")
                RLStatusLine(text: model.isRunning ? "Running…" : (ok ? "✓ " : "") + model.status,
                             isError: !model.isRunning && !ok && model.status.hasPrefix("Could not"),
                             isOK: ok)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .frame(maxHeight: maxOutputHeight == nil ? .infinity : nil, alignment: .top)
    }

    private var divider: some View { Rectangle().fill(Color.rlLine).frame(height: 1) }

    private var outputText: Text {
        model.chunks.reduce(Text("")) { text, chunk in
            text + Text(chunk.text).foregroundColor(chunk.isError ? .red : Color.rlInk)
        }
    }
}
