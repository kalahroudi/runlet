import Testing
@testable import RunLetCore

struct AppearanceChoiceTests {
    @Test func readsStoredValues() {
        #expect(AppearanceChoice(stored: "dark") == .dark)
        #expect(AppearanceChoice(stored: "light") == .light)
    }

    @Test func unknownOrMissingMeansSystem() {
        #expect(AppearanceChoice(stored: nil) == .system)
        #expect(AppearanceChoice(stored: "purple") == .system)
    }
}
