import Testing
@testable import RunLetCore

struct PaletteTests {
    @Test func splitsHexIntoChannels() {
        let c = Hex(0xFF8000)
        #expect(c.red == 1)
        #expect(abs(c.green - 128.0 / 255) < 1e-9)
        #expect(c.blue == 0)
    }

    @Test func contrastExtremes() {
        #expect(abs(Hex.contrast(Hex(0x000000), Hex(0xFFFFFF)) - 21) < 1e-9)
        #expect(Hex.contrast(Hex(0x123456), Hex(0x123456)) == 1)
    }

    @Test func textIsReadableOnSurfacesInBothAppearances() {
        for text in [Palette.ink, Palette.muted] {
            for surface in [Palette.surface, Palette.surface2, Palette.background] {
                #expect(Hex.contrast(text.light, surface.light) >= 4.5)
                #expect(Hex.contrast(text.dark, surface.dark) >= 4.5)
            }
        }
    }

    @Test func okIsReadableOnCodeBackground() {
        #expect(Hex.contrast(Palette.ok.light, Palette.codeBackground.light) >= 3)
        #expect(Hex.contrast(Palette.ok.dark, Palette.codeBackground.dark) >= 4.5)
    }
}
