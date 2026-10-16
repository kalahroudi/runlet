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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.title).font(RLFont.display(18))
                Spacer()
                SaveIndicator(state: model.saveState)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rectangle().fill(Color.rlLine).frame(height: 1)
            if model.usesFallback {
                VStack(alignment: .leading, spacing: 0) {
                    Text("The code editor could not load, so this is a plain text box. Your text still saves.")
                        .font(RLFont.body(12)).foregroundStyle(Color.rlMuted).padding(10)
                    TextEditor(text: $model.text).font(RLFont.mono(13))
                        .scrollContentBackground(.hidden).background(Color.rlCode)
                }
            } else {
                EditorView(text: $model.text, onFailure: { model.usesFallback = true })
                    .background(Color.rlCode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rlBackground)
        .onAppear { model.open() }
        .onDisappear { model.flush() }
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
