import Observation

/// The word list: what it shows, and the rows it loaded. The view reloads it with `.task(id: model.query)`.
@MainActor
@Observable
public final class WordListModel {
    public var topic = Topic.all
    public var search = ""
    public private(set) var entries: [WordEntry] = []
    public private(set) var failed = false

    @ObservationIgnored private let library: Library
    @ObservationIgnored private let settings: SettingsModel

    public init(library: Library, settings: SettingsModel) {
        self.library = library
        self.settings = settings
    }

    public var query: WordListQuery {
        WordListQuery(topic: topic, search: search, settings: settings.list)
    }

    public func load() async {
        let query = query
        do {
            let entries = try await library.words(query)
            // A newer query may have started while this one ran; its rows are the ones to show.
            guard query == self.query else { return }
            self.entries = entries
            failed = false
        } catch {
            if query == self.query { failed = true }
        }
    }

    /// A bookmark was added or removed: the list shows them only in bookmarks mode.
    public func bookmarksChanged() async {
        if topic == .bookmarks { await load() }
    }
}
