import Foundation

public enum Language: String, CaseIterable, Sendable {
    case python, javascript, typescript, go, rust

    public var displayName: String {
        switch self {
        case .python: "Python"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .go: "Go"
        case .rust: "Rust"
        }
    }
}

/// Guesses the language of pasted code. Crude on purpose: the first rule that matches wins.
public enum LanguageDetector {
    public static func detect(_ source: String) -> Language? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 10 else { return nil }
        if matches(#"\bfunc\b[^\n]*\{"#, text) || text.contains("package main") { return .go }
        if matches(#"\bfn\b[^\n]*\{"#, text) || text.contains("let mut") { return .rust }
        if text.contains(": string") || text.contains(": number") || matches(#"\binterface\b"#, text) { return .typescript }
        if matches(#"\bconst\b"#, text) || text.contains("=>") || text.contains("console.log") { return .javascript }
        if matches(#"\bdef\b"#, text) || matches(#"\bimport\b"#, text) || text.contains("print(") { return .python }
        return nil
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
