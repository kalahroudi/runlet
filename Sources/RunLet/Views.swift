import SwiftUI

struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RunLet").font(.title2.weight(.bold))
            Text("Quick code, anywhere.").foregroundStyle(.secondary)
            Divider()
            ScratchRunView()
            Divider()
            HStack {
                Button("Open in window") { AppWindows.main.show() }
                Button("Settings…") { AppActivation.openSettings() }
                    .keyboardShortcut(",")
                Button("Update") { AppActivation.openSettings(); UpdateModel.shared.check() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

struct MainWindowView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("RunLet").font(.largeTitle.weight(.bold))
            Text("Your playground will live here.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            UpdateSection()
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("General", systemImage: "gearshape") }
            Text("Connected agents will appear here.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("Agents", systemImage: "sparkles") }
        }
        .frame(width: 460, height: 300)
    }
}
