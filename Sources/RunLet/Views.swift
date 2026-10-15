import SwiftUI

struct PopoverView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RunLet").font(RLFont.display(24))
                    Text("Quick code, anywhere.").font(RLFont.body(13)).foregroundStyle(Color.rlMuted)
                }
                UpdateBanner()
                RLCard { ScratchRunView() }
            }
            .padding(14)

            HStack(spacing: 8) {
                Button("Open in window ↗") { AppWindows.main.show() }.buttonStyle(.rlSmall)
                Button("Settings…") { AppActivation.openSettings() }
                    .buttonStyle(.rlSmall).keyboardShortcut(",")
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.rlSmall).keyboardShortcut("q")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.rlSurface2)
            .overlay(alignment: .top) { Rectangle().fill(Color.rlLine).frame(height: 1) }
        }
        .frame(width: 380)
        .background(Color.rlBackground)
    }
}

struct MainWindowView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("RunLet").font(RLFont.display(40))
            Text("Your playground will live here.").font(RLFont.body(15)).foregroundStyle(Color.rlMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rlBackground)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings").font(RLFont.display(22))
                RLCard { AppearanceSection().frame(maxWidth: .infinity, alignment: .leading) }
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
        .frame(width: 460, height: 400)
    }
}
