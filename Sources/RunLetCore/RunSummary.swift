import Foundation

extension RunResult {
    /// One line for the status bar, such as "Finished in 38 ms".
    public func summary(timeLimit: TimeInterval) -> String {
        switch outcome {
        case .exited where exitCode == 0:
            return "Finished in \(Self.format(duration))"
        case .exited:
            return "Exited with code \(exitCode ?? -1) in \(Self.format(duration))"
        case .timedOut:
            return "Stopped after \(Self.format(timeLimit)) (time limit)"
        case .failedToLaunch(let reason):
            return "Could not start: \(reason)"
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
            .replacingOccurrences(of: ".0 s", with: " s")
    }
}
