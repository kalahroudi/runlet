/// The appearance the person picked in Settings. `system` follows macOS.
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system, light, dark

    public static let defaultsKey = "appearance"

    /// Unknown or missing stored values mean `system`.
    public init(stored: String?) {
        self = stored.flatMap(AppearanceChoice.init(rawValue:)) ?? .system
    }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
