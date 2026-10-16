import Foundation

/// How long a run may last, as picked in Settings.
public enum TimeLimitChoice: String, CaseIterable, Sendable {
    case tenSeconds = "10", oneMinute = "60", fiveMinutes = "300", none

    public static let defaultsKey = "timeLimit"

    /// Unknown or missing stored values mean one minute.
    public init(stored: String?) {
        self = stored.flatMap(TimeLimitChoice.init(rawValue:)) ?? .oneMinute
    }

    /// Seconds, or `nil` for no limit.
    public var seconds: TimeInterval? { TimeInterval(rawValue) }

    public var title: String {
        switch self {
        case .tenSeconds: "10 s"
        case .oneMinute: "60 s"
        case .fiveMinutes: "5 min"
        case .none: "None"
        }
    }
}
