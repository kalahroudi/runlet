import SwiftUI
import RunLetCore

@MainActor
final class UpdateModel: ObservableObject {
    static let shared = UpdateModel()

    @Published var status = "Not checked yet"
    @Published var log = ""
    @Published var isBusy = false
    @Published var canUpdate = false

    let installedCommit = Bundle.main.object(forInfoDictionaryKey: "RunLetCommit") as? String ?? "unknown"
    static var logURL: URL { InstallInfo.defaultURL.deletingLastPathComponent().appendingPathComponent("update.log") }
    private var task: Task<Void, Never>?
    private var timer: Timer?

    /// Checks shortly after launch and then every six hours, so an available update shows up without anyone asking.
    func startAutoChecks() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in UpdateModel.shared.check() }
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            check()
        }
    }

    func check() {
        guard !isBusy else { return }
        isBusy = true; status = "Checking…"; log = ""
        task = Task {
            let (info, git) = await load()
            let s = UpdatePlanner.status(info: info, git: git)
            status = s.text
            canUpdate = { if case .behind = s { true } else { false } }()
            isBusy = false
        }
    }

    func update() {
        guard !isBusy else { return }
        isBusy = true; log = ""; status = "Updating…"
        task = Task {
            let (info, git) = await load()
            if let why = UpdatePlanner.refusal(info: info, git: git) {
                status = why; isBusy = false; return
            }
            guard let info else { return }
            let repo = URL(fileURLWithPath: info.repo)
            let pull = await GitClient.run(["merge", "--ff-only", "origin/main"], in: repo)
            guard pull.code == 0 else {
                status = "Could not fast-forward main."; log = pull.out; try? log.write(to: Self.logURL, atomically: true, encoding: .utf8); isBusy = false; return
            }
            // install.sh builds first and only then replaces and relaunches the app, so a failed build leaves this app running.
            var failed = false
            let request = RunRequest(executable: URL(fileURLWithPath: "/bin/bash"), arguments: ["scripts/install.sh"],
                                     workingDirectory: repo, timeout: 600)
            for await event in ProcessRunner.run(request) {
                switch event {
                case .output(_, let text): log += text
                case .finished(let r): failed = r.outcome != .exited || r.exitCode != 0
                }
            }
            if failed { status = "The update failed. The old version is still installed. Log: \(Self.logURL.path)" }
            try? log.write(to: Self.logURL, atomically: true, encoding: .utf8)
            isBusy = false
        }
    }

    func stop() { task?.cancel(); isBusy = false; status = "Stopped" }

    private func load() async -> (InstallInfo?, GitState?) {
        guard let info = InstallInfo.load() else { return (nil, nil) }
        return (info, await GitClient.state(for: info))
    }
}

struct UpdateSection: View {
    @ObservedObject var model = UpdateModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RLSectionTitle("Version")
            Text(String(model.installedCommit.prefix(7))).font(RLFont.mono(13))
            HStack {
                Button("Check for updates") { model.check() }.buttonStyle(.rl).disabled(model.isBusy)
                if model.isBusy { Button("Stop") { model.stop() }.buttonStyle(.rl) }
            }
            Text(model.status).font(RLFont.body(13)).foregroundStyle(Color.rlMuted)
            if model.canUpdate && !model.isBusy {
                Text("Use the Update button in the menu bar popover.").font(RLFont.body(12)).foregroundStyle(Color.rlMuted)
            }
            if !model.log.isEmpty {
                ScrollView { Text(model.log).font(RLFont.mono(11)).frame(maxWidth: .infinity, alignment: .leading) }
                    .scrollIndicators(.hidden).frame(height: 80)
            }
        }
    }
}

/// Shown at the top of the popover only while an update is available.
struct UpdateBanner: View {
    @ObservedObject var model = UpdateModel.shared

    var body: some View {
        if model.canUpdate {
            RLBanner(icon: "arrow.down.circle.fill", text: model.status) {
                if model.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Update") { model.update() }.buttonStyle(.rlSmallPrimary)
                }
            }
        }
    }
}
