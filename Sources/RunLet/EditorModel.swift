import Foundation
import Combine
import RunLetCore

/// The snippet shown in the main window's editor, saved as the person types.
@MainActor
final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    @Published var text = "" {
        didSet { if loaded, text != oldValue { autosaver.change(text) } }
    }
    @Published private(set) var title = ""
    @Published private(set) var saveState = Autosaver.State.idle
    @Published var usesFallback = false

    private let store: SnippetStore
    private let autosaver: Autosaver
    private var snippetID = ""
    private var loaded = false
    private var bag = Set<AnyCancellable>()

    init(store: SnippetStore = SnippetStore()) {
        self.store = store
        let id = IDBox()
        self.autosaver = Autosaver { [id, store] text in _ = try store.save(source: text, for: id.value) }
        self.idBox = id
        autosaver.$state.sink { [weak self] in self?.saveState = $0 }.store(in: &bag)
    }

    private let idBox: IDBox
    private final class IDBox: @unchecked Sendable { var value = "" }

    /// Opens the newest snippet, or makes an empty one the first time.
    func open() {
        guard !loaded else { return }
        let snippet = store.list().first ?? (try? store.create(source: ""))
        guard let snippet else { return }
        snippetID = snippet.id
        idBox.value = snippet.id
        title = snippet.title
        text = (try? store.source(of: snippet.id)) ?? ""
        loaded = true
    }

    /// Saves anything still waiting. Called when the window closes.
    func flush() { autosaver.flush() }
}
