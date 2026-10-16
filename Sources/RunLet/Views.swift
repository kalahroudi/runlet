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
