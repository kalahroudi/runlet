import Foundation
import Combine
import RunLetCore

/// The main window's editor. It shows the same snippet as the popover (`QuickRunModel.shared`), and saves
/// edits a moment after typing stops.
@MainActor
final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    let run = QuickRunModel.shared
    @Published private(set) var saveState = Autosaver.State.idle
    @Published var usesFallback = false

    private let autosaver: Autosaver
    private var bag = Set<AnyCancellable>()

    init() {
        let run = QuickRunModel.shared
        autosaver = Autosaver { _ in try run.saveCurrent() }
        autosaver.$state.sink { [weak self] in self?.saveState = $0 }.store(in: &bag)
    }

    /// Opens the newest snippet when the window starts with an empty box.
    func openIfEmpty() {
        guard run.currentID == nil, run.source.isEmpty, let newest = run.all.first else { return }
        run.select(newest)
    }

    /// Call on every edit. Loading a snippet is not an edit.
    func textChanged() {
        if run.isDirty { autosaver.change(run.source) }
    }

    /// Saves anything still waiting and stops a run in progress. Called when the window closes.
    func windowClosed() {
        autosaver.flush()
        run.stop()
    }
}
