import Foundation

public enum CleanMode: Sendable {
    /// Pasted text: may also remove lines (Markdown fences, shell prompts).
    case paste
    /// Just before a run: never adds or removes lines, so error line numbers match the box.
    case run
}

public struct CleanResult: Equatable, Sendable {
    public var text: String
    /// What was changed, in the order applied, for example "indent removed".
    public var changes: [String]

    /// "Cleaned pasted code: indent removed. ⌘Z to undo." or "Ran with indent removed.", nil when nothing changed.
    public func notice(for mode: CleanMode) -> String? {
        guard !changes.isEmpty else { return nil }
        let list = changes.joined(separator: ", ")
        return mode == .paste ? "Cleaned pasted code: \(list). ⌘Z to undo." : "Ran with \(list)."
    }
}

/// Fixes damage that copy and paste does to Python code, and nothing else. Pure and idempotent.
public enum CodeCleaner {
    public static func clean(_ input: String, mode: CleanMode) -> CleanResult {
        var text = input
        var changes: [String] = []
        func apply(_ name: String, _ change: (String) -> String) {
            let next = change(text)
            if next != text { text = next; changes.append(name) }
        }

        apply("line endings fixed") { $0.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") }
        apply("hidden characters removed") { String($0.unicodeScalars.filter { !hidden.contains($0) }) }
        apply("spaces fixed") { String(String.UnicodeScalarView($0.unicodeScalars.map { odd.contains($0) ? " " : $0 })) }
        if mode == .paste {
            apply("markdown fence removed", removeFence)
            apply("prompts removed", removePrompts)
        }
        apply("tabs fixed", fixMixedTabs)
        apply("indent removed", dedent)
        apply("quotes fixed", straightenQuotes)
        return CleanResult(text: text, changes: changes)
    }

    private static let hidden: Set<Unicode.Scalar> = ["\u{FEFF}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}"]
    private static let odd: Set<Unicode.Scalar> = {
        var s: Set<Unicode.Scalar> = ["\u{00A0}", "\u{202F}", "\u{205F}", "\u{3000}"]
        for v in 0x2000...0x200A { s.insert(Unicode.Scalar(v)!) }
        return s
    }()

    private static func lines(_ s: String) -> [String] { s.components(separatedBy: "\n") }
    private static func isBlank(_ s: String) -> Bool { s.allSatisfy { $0 == " " || $0 == "\t" } }

    // MARK: Fences

    private static func removeFence(_ s: String) -> String {
        var l = lines(s)
        guard let first = l.firstIndex(where: { !isBlank($0) }) else { return s }
        let opener = l[first].trimmingCharacters(in: .whitespaces)
        guard opener.hasPrefix("```"), opener.dropFirst(3).allSatisfy({ $0.isLetter || $0.isNumber }) else { return s }
        l.remove(at: first)
        if let last = l.lastIndex(where: { !isBlank($0) }), l[last].trimmingCharacters(in: .whitespaces) == "```" {
            l.remove(at: last)
        }
        return l.joined(separator: "\n")
    }

    // MARK: Shell prompts

    private static func removePrompts(_ s: String) -> String {
        let l = lines(s)
        let nonBlank = l.filter { !isBlank($0) }
        func promptBody(_ line: String) -> String? {
            let t = line.drop { $0 == " " }
            for p in [">>> ", "... "] where t.hasPrefix(p) { return String(t.dropFirst(p.count)) }
            if t == ">>>" || t == "..." { return "" }
            return nil
        }
        guard let firstLine = nonBlank.first, firstLine.drop(while: { $0 == " " }).hasPrefix(">>>") else { return s }
        let prompted = nonBlank.filter { promptBody($0) != nil }.count
        guard prompted * 2 >= nonBlank.count else { return s }
        return l.compactMap { promptBody($0) }.joined(separator: "\n")
    }

    // MARK: Tabs and indent

    private static func leading(_ line: String) -> Substring { line.prefix { $0 == " " || $0 == "\t" } }

    private static func fixMixedTabs(_ s: String) -> String {
        let l = lines(s)
        let lead = l.filter { !isBlank($0) }.map(leading)
        guard lead.contains(where: { $0.contains("\t") }), lead.contains(where: { $0.contains(" ") }) else { return s }
        return l.map { line in
            let lead = leading(line)
            return lead.replacingOccurrences(of: "\t", with: "    ") + line.dropFirst(lead.count)
        }.joined(separator: "\n")
    }

    private static func dedent(_ s: String) -> String {
        var l = lines(s)
        let idx = l.indices.filter { !isBlank(l[$0]) }
        guard let first = idx.first else { return s }
        func common(_ rows: [Int]) -> String {
            guard var prefix = rows.first.map({ String(leading(l[$0])) }) else { return "" }
            for r in rows.dropFirst() {
                prefix = String(zip(prefix, leading(l[r])).prefix { $0 == $1 }.map { $0.0 })
            }
            return prefix
        }
        var rows = idx
        var shared = common(rows)
        if shared.isEmpty, leading(l[first]).isEmpty, idx.count > 1, !continues(l[first]) {
            // The first line lost its indent (copied from mid-line); the rest share one.
            rows = Array(idx.dropFirst())
            shared = common(rows)
            guard !shared.isEmpty else { return s }
            for r in rows { l[r] = String(l[r].dropFirst(shared.count)) }
        } else {
            guard !shared.isEmpty else { return s }
            for r in l.indices { if l[r].hasPrefix(shared) { l[r] = String(l[r].dropFirst(shared.count)) } else if isBlank(l[r]) { l[r] = "" } }
        }
        return l.joined(separator: "\n")
    }

    /// A first line that legitimately expects an indented or continued next line.
    private static func continues(_ line: String) -> Bool {
        guard let last = line.trimmingCharacters(in: .whitespaces).last else { return true }
        return ":,\\([{".contains(last) || line.contains("\"\"\"") || line.contains("'''")
    }

    // MARK: Curly quotes

    private static let curlyDouble: Set<Character> = ["“", "”"]
    private static let curlySingle: Set<Character> = ["‘", "’"]

    /// Curly quotes become straight only when they delimit a string outside strings and comments.
    private static func straightenQuotes(_ s: String) -> String {
        guard s.contains(where: { curlyDouble.contains($0) || curlySingle.contains($0) }) else { return s }
        let c = Array(s)
        var out: [Character] = []
        var i = 0
        while i < c.count {
            let ch = c[i]
            if ch == "#" {                                   // comment: copy to end of line
                while i < c.count, c[i] != "\n" { out.append(c[i]); i += 1 }
            } else if ch == "\"" || ch == "'" {              // straight string, single or triple
                let triple = i + 2 < c.count && c[i + 1] == ch && c[i + 2] == ch
                let n = triple ? 3 : 1
                out.append(contentsOf: c[i..<i + n]); i += n
                while i < c.count {
                    if c[i] == "\\", i + 1 < c.count { out.append(contentsOf: c[i...i + 1]); i += 2; continue }
                    if c[i] == ch, !triple || (i + 2 < c.count && c[i + 1] == ch && c[i + 2] == ch) {
                        out.append(contentsOf: c[i..<i + n]); i += n; break
                    }
                    if c[i] == "\n", !triple { break }
                    out.append(c[i]); i += 1
                }
            } else if curlyDouble.contains(ch) || curlySingle.contains(ch) {
                let isDouble = curlyDouble.contains(ch)
                let set = isDouble ? curlyDouble : curlySingle
                let straight: Character = isDouble ? "\"" : "'"
                var j = i + 1
                while j < c.count, c[j] != "\n", !set.contains(c[j]), c[j] != straight { j += 1 }
                if j < c.count, c[j] != "\n" {
                    out.append(straight); out.append(contentsOf: c[(i + 1)..<j]); out.append(straight); i = j + 1
                } else { out.append(ch); i += 1 }
            } else { out.append(ch); i += 1 }
        }
        return String(out)
    }
}
