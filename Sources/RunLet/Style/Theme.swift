import SwiftUI
import AppKit
import CoreText
import RunLetCore

extension Color {
    /// A colour that follows the system light or dark appearance.
    init(_ token: Token) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? token.dark : token.light
            return NSColor(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
        })
    }

    static let rlBackground = Color(Palette.background)
    static let rlSurface = Color(Palette.surface)
    static let rlSurface2 = Color(Palette.surface2)
    static let rlLine = Color(Palette.line)
    static let rlInk = Color(Palette.ink)
    static let rlMuted = Color(Palette.muted)
    static let rlAccent = Color(Palette.accent)
    static let rlAccentSoft = Color(Palette.accentSoft)
    static let rlOK = Color(Palette.ok)
    static let rlCode = Color(Palette.codeBackground)
}

/// Bundled fonts from the mock. Each falls back to a system font if it did not load.
enum RLFont {
    private static let registered: Void = {
        for name in ["BricolageGrotesque", "InstrumentSans", "JetBrainsMono"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    static func load() { registered }

    private static func has(_ family: String) -> Bool {
        load()
        return NSFontManager.shared.availableFontFamilies.contains(family)
    }

    static func display(_ size: CGFloat) -> Font {
        has("Bricolage Grotesque") ? .custom("Bricolage Grotesque", size: size).weight(.bold)
                                   : .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        has("Instrument Sans") ? .custom("Instrument Sans", size: size).weight(weight)
                               : .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        has("JetBrains Mono") ? .custom("JetBrains Mono", size: size)
                              : .system(size: size, design: .monospaced)
    }
}
