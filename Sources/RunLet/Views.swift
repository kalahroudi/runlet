import SwiftUI
import RunLetCore

struct PopoverView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                UpdateBanner()
                QuickRunView()
            }
            .padding(12)

            HStack(spacing: 2) {
                Text("RunLet · \(String(UpdateModel.shared.installedCommit.prefix(7)))")
                    .font(RLFont.body(12)).foregroundStyle(Color.rlMuted)
                Spacer()
                Button { StatusBarController.shared.close(); AppWindows.main.show() } label: {
                    Image(systemName: "arrow.up.forward.square")
                }.buttonStyle(.rlIcon).help("Open in window")
                Button { StatusBarController.shared.close(); AppActivation.openSettings() } label: {
                    Image(systemName: "gearshape")
                }.buttonStyle(.rlIcon).help("Settings (⌘,)").keyboardShortcut(",")
                Button { StatusBarController.shared.close(); NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }.buttonStyle(.rlIcon).help("Quit RunLet (⌘Q)").keyboardShortcut("q")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.rlSurface2)
            .overlay(alignment: .top) { Rectangle().fill(Color.rlLine).frame(height: 1) }
        }
        .frame(width: 380)
    }
}

struct MainWindowView: View {
    @ObservedObject private var model = EditorModel.shared
    @ObservedObject private var run = QuickRunModel.shared

    var body: some View {
        HSplitView {
            SnippetList(run: run)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Color.rlLine).frame(height: 1)
                VSplitView {
                    editor.frame(minHeight: 160)
                    ConsoleView(model: run, maxOutputHeight: nil)
                        .background(Color.rlCode)
                        .frame(minHeight: 100, idealHeight: 180)
                }
            }
            .frame(minWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rlBackground)
        .onAppear { model.openIfEmpty() }
        .onChange(of: run.source) { _, _ in model.textChanged() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(run.all.first { $0.id == run.currentID }?.title ?? "New snippet")
                .font(RLFont.display(18)).lineLimit(1)
            Spacer()
            SaveIndicator(state: model.saveState)
            if run.isRunning {
                Button("Stop", action: run.stop).buttonStyle(.rlSmall)
            } else {
                Button("▶ Run", action: run.startRun)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.rlSmallPrimary)
                    .disabled(!run.canRun)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    @ViewBuilder private var editor: some View {
        if model.usesFallback {
            VStack(alignment: .leading, spacing: 0) {
                Text("The code editor could not load, so this is a plain text box. Your text still saves.")
                    .font(RLFont.body(12)).foregroundStyle(Color.rlMuted).padding(10)
                TextEditor(text: $run.source).font(RLFont.mono(13))
                    .scrollContentBackground(.hidden).noScrollers().background(Color.rlCode)
            }
        } else {
            EditorView(text: $run.source, onFailure: { model.usesFallback = true })
                .background(Color.rlCode)
        }
    }
}

private struct SnippetList: View {
    @ObservedObject var run: QuickRunModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                RLSectionTitle("Snippets")
                Spacer()
                Button { run.startNew() } label: { Image(systemName: "plus") }
                    .buttonStyle(.rlIcon).help("New snippet")
            }
            .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
            StyledScrollView(fade: Color.rlSurface2) {
                VStack(spacing: 2) {
                    ForEach(run.all) { snippet in
                        SnippetRow(snippet: snippet, selected: snippet.id == run.currentID,
                                   open: { run.select(snippet) }, delete: { run.delete(snippet) })
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.rlSurface2)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let selected: Bool
    let open: () -> Void
    let delete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Language.python.dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(snippet.title).font(RLFont.body(13, .medium)).foregroundStyle(Color.rlInk).lineLimit(1)
                Text(RelativeTime.text(for: snippet.modified)).font(RLFont.body(11.5)).foregroundStyle(Color.rlMuted)
            }
            Spacer(minLength: 4)
            if hovering {
                Button(action: delete) { Image(systemName: "trash") }
                    .buttonStyle(.rlIcon).help("Move to Trash")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(selected ? Color.rlAccentSoft : (hovering ? Color.rlLine.opacity(0.5) : .clear),
                    in: RoundedRectangle(cornerRadius: 9))
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(perform: open)
        .onHover { hovering = $0 }
        .contextMenu { Button("Move to Trash", action: delete) }
    }
}

private struct SaveIndicator: View {
    let state: Autosaver.State

    var body: some View {
        Text(label).font(RLFont.body(12)).foregroundStyle(isError ? Color.red : Color.rlMuted)
    }

    private var isError: Bool { if case .failed = state { true } else { false } }

    private var label: String {
        switch state {
        case .idle: ""
        case .pending: "Saving…"
        case .saved(let date): "Saved " + date.formatted(date: .omitted, time: .shortened)
        case .failed(let message): "Could not save: \(message)"
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings").font(RLFont.display(22))
                RLCard { AppearanceSection().frame(maxWidth: .infinity, alignment: .leading) }
                RLCard { TimeLimitSection().frame(maxWidth: .infinity, alignment: .leading) }
                RLCard { UpdateSection().frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.rlBackground)
                .tabItem { Label("General", systemImage: "gearshape") }
            Text("Connected agents will appear here.")
                .font(RLFont.body(14)).foregroundStyle(Color.rlMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.rlBackground)
                .tabItem { Label("Agents", systemImage: "sparkles") }
        }
        .frame(width: 460, height: 470)
    }
}
