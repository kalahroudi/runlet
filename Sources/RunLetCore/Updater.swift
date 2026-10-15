import Foundation

/// What `scripts/install.sh` recorded when it installed the app.
public struct InstallInfo: Codable, Equatable, Sendable {
    public var repo: String
    public var commit: String

    public init(repo: String, commit: String) {
        self.repo = repo
        self.commit = commit
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RunLet/install.json")
    }

    public static func load(from url: URL = defaultURL) -> InstallInfo? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(InstallInfo.self, from: data)
    }
}

/// The facts about the source folder that the update decision needs.
public struct GitState: Equatable, Sendable {
    public var branch: String
    public var isDirty: Bool
    /// Commits on `origin/main` that the installed commit does not have. Nil when it could not be worked out.
    public var behind: Int?

    public init(branch: String, isDirty: Bool, behind: Int?) {
        self.branch = branch
        self.isDirty = isDirty
        self.behind = behind
    }
}

public enum UpdateStatus: Equatable, Sendable {
    case upToDate
    case behind(Int)
    case unavailable(String)

    public var text: String {
        switch self {
        case .upToDate: "Up to date"
        case .behind(let n): n == 1 ? "1 new change" : "\(n) new changes"
        case .unavailable(let why): why
        }
    }
}

public enum UpdatePlanner {
    public static let notFromSource = "RunLet was not installed from source. Re-run scripts/install.sh once."

    public static func status(info: InstallInfo?, git: GitState?) -> UpdateStatus {
        guard let info else { return .unavailable(notFromSource) }
        guard let git else {
            return .unavailable("The folder \(info.repo) was not found or is not a git repository.")
        }
        guard let behind = git.behind else {
            return .unavailable("Could not compare this app with the latest main.")
        }
        return behind == 0 ? .upToDate : .behind(behind)
    }

    /// The reason an update must not start, or nil when it may.
    public static func refusal(info: InstallInfo?, git: GitState?) -> String? {
        if case .unavailable(let why) = status(info: info, git: git) { return why }
        guard let git else { return nil }
        if git.branch != "main" { return "The source folder is on branch \(git.branch), not main." }
        if git.isDirty { return "The source folder has uncommitted changes. Commit or stash them first." }
        return nil
    }
}

public enum GitClient {
    static let git = URL(fileURLWithPath: "/usr/bin/git")

    /// Runs git in `repo` and returns the exit code with trimmed stdout.
    public static func run(_ args: [String], in repo: URL, timeout: TimeInterval = 60) async -> (code: Int32?, out: String) {
        var out = ""
        var code: Int32?
        // Never prompt, never wait for a password, and never take the index lock, so a background check cannot
        // interrupt the person or collide with their own git commands.
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
        environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
        let request = RunRequest(executable: git, arguments: args, workingDirectory: repo,
                                 environment: environment, timeout: timeout)
        for await event in ProcessRunner.run(request) {
            switch event {
            case .output(.stdout, let s): out += s
            case .output(.stderr, _): break
            case .finished(let r): code = r.outcome == .exited ? r.exitCode : nil
            }
        }
        return (code, out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Fetches `origin/main` and reads the state of the source folder. Nil when it is not a git repository.
    public static func state(for info: InstallInfo, fetch: Bool = true) async -> GitState? {
        let repo = URL(fileURLWithPath: info.repo)
        guard FileManager.default.fileExists(atPath: info.repo) else { return nil }
        if fetch { _ = await run(["fetch", "--quiet", "--no-tags", "origin", "main"], in: repo, timeout: 30) }
        let branch = await run(["rev-parse", "--abbrev-ref", "HEAD"], in: repo)
        guard branch.code == 0 else { return nil }
        let dirty = await run(["status", "--porcelain"], in: repo)
        let count = await run(["rev-list", "--count", "\(info.commit)..origin/main"], in: repo)
        return GitState(branch: branch.out, isDirty: !dirty.out.isEmpty, behind: count.code == 0 ? Int(count.out) : nil)
    }
}
