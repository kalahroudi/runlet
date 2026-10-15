import Foundation
import Testing
@testable import RunLetCore

struct UpdaterTests {
    let info = InstallInfo(repo: "/src/runlet", commit: "abc")
    func git(branch: String = "main", dirty: Bool = false, behind: Int? = 0) -> GitState {
        GitState(branch: branch, isDirty: dirty, behind: behind)
    }

    @Test func upToDateAndBehind() {
        #expect(UpdatePlanner.status(info: info, git: git()) == .upToDate)
        #expect(UpdatePlanner.status(info: info, git: git(behind: 1)).text == "1 new change")
        #expect(UpdatePlanner.status(info: info, git: git(behind: 3)).text == "3 new changes")
    }

    @Test func missingInstallFile() {
        #expect(UpdatePlanner.status(info: nil, git: nil) == .unavailable(UpdatePlanner.notFromSource))
        #expect(UpdatePlanner.refusal(info: nil, git: nil) == UpdatePlanner.notFromSource)
    }

    @Test func missingRepoOrUnknownComparison() {
        #expect(UpdatePlanner.refusal(info: info, git: nil)?.contains("/src/runlet") == true)
        #expect(UpdatePlanner.refusal(info: info, git: git(behind: nil)) != nil)
    }

    @Test func refusesDirtyOrWrongBranchButStillChecks() {
        #expect(UpdatePlanner.status(info: info, git: git(dirty: true, behind: 2)) == .behind(2))
        #expect(UpdatePlanner.refusal(info: info, git: git(dirty: true, behind: 2))?.contains("uncommitted") == true)
        #expect(UpdatePlanner.refusal(info: info, git: git(branch: "feature", behind: 2))?.contains("feature") == true)
        #expect(UpdatePlanner.refusal(info: info, git: git(behind: 2)) == nil)
    }

    @Test func readsGitStateFromARealRepo() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("upd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func g(_ a: [String]) async { _ = await GitClient.run(a, in: dir) }
        await g(["init", "-q", "-b", "main"])
        await g(["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "one"])
        let head = await GitClient.run(["rev-parse", "HEAD"], in: dir).out
        let state = await GitClient.state(for: InstallInfo(repo: dir.path, commit: head), fetch: false)
        #expect(state?.branch == "main")
        #expect(state?.isDirty == false)
    }
}
