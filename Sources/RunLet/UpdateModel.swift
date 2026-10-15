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
    private var task: Task<Void, Never>?

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
                status = "Could not fast-forward main."; log = pull.out; isBusy = false; return
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
            if failed { status = "The update failed. The old version is still installed." }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Version \(String(model.installedCommit.prefix(7)))").font(.callout.monospaced())
            HStack {
                Button("Check for updates") { model.check() }.disabled(model.isBusy)
                Button("Update RunLet") { model.update() }.disabled(model.isBusy || !model.canUpdate)
                if model.isBusy { Button("Stop") { model.stop() } }
            }
            Text(model.status).foregroundStyle(.secondary)
            if !model.log.isEmpty {
                ScrollView { Text(model.log).font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading) }
                    .scrollIndicators(.hidden).frame(height: 80)
            }
        }
    }
}
