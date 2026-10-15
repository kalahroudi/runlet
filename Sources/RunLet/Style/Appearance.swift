import SwiftUI
import AppKit
import RunLetCore

enum Appearance {
    /// Applies the saved choice to every window of the app.
    static func apply(_ choice: AppearanceChoice = current) {
        switch choice {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static var current: AppearanceChoice {
        AppearanceChoice(stored: UserDefaults.standard.string(forKey: AppearanceChoice.defaultsKey))
    }
}

struct AppearanceSection: View {
    @AppStorage(AppearanceChoice.defaultsKey) private var stored = AppearanceChoice.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RLSectionTitle("Appearance")
            Picker("Appearance", selection: $stored) {
                ForEach(AppearanceChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: stored) { _, new in Appearance.apply(AppearanceChoice(stored: new)) }
        }
    }
}
