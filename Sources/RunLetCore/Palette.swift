import Foundation

/// A colour as 0xRRGGBB.
public struct Hex: Equatable, Sendable {
    public var value: UInt32
    public init(_ value: UInt32) { self.value = value }

    public var red: Double { Double((value >> 16) & 0xFF) / 255 }
    public var green: Double { Double((value >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(value & 0xFF) / 255 }

    /// WCAG relative luminance.
    public var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 to 21.
    public static func contrast(_ a: Hex, _ b: Hex) -> Double {
        let (hi, lo) = (max(a.luminance, b.luminance), min(a.luminance, b.luminance))
        return (hi + 0.05) / (lo + 0.05)
    }
}

public struct Token: Equatable, Sendable {
    public var light: Hex
    public var dark: Hex
    init(_ light: UInt32, _ dark: UInt32) { self.light = Hex(light); self.dark = Hex(dark) }
}

/// Colours from the approved mock (`docs/mock/runlet.html`).
public enum Palette {
    public static let background = Token(0xEEF1F5, 0x0E1116)
    public static let surface = Token(0xFFFFFF, 0x171B22)
    public static let surface2 = Token(0xF6F8FB, 0x1D222B)
    public static let line = Token(0xDDE2EA, 0x2B323E)
    public static let ink = Token(0x14181F, 0xEDF0F5)
    public static let muted = Token(0x5F6B7E, 0x9AA4B5)
    public static let accent = Token(0xFF5B2E, 0xFF6B42)
    public static let accentSoft = Token(0xFFE9E2, 0x3A2018)
    public static let ok = Token(0x12A37A, 0x34D3A0)
    public static let codeBackground = Token(0xFBFCFD, 0x12161C)
}
