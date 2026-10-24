import Foundation
import Testing

@testable import DrevoKit

@MainActor
struct WordListModelTests {
    private let library: Library
    private let settings = SettingsModel(defaults: UserDefaults(suiteName: UUID().uuidString)!)

    init() throws {
        library = try Fixtures.library()
    }

    @Test func loadsAllArticlesFirst() async {
        let model = WordListModel(library: library, settings: settings)
        await model.load()
        #expect(model.entries.first?.id == 4)
        #expect(!model.failed)
    }

    @Test func loadsWhatTopicAndSearchSelect() async {
        let model = WordListModel(library: library, settings: settings)
        model.topic = .persons
        model.search = "сер"
        await model.load()
        #expect(model.entries.map(\.id) == [102])
    }

    @Test func followsTheListSettings() async {
        let model = WordListModel(library: library, settings: settings)
        model.search = "радонеж"
        settings.list.searchMatch = .prefix
        #expect(model.query.settings.searchMatch == .prefix)
        await model.load()
        #expect(model.entries.isEmpty)
    }

    @Test func reloadsAfterABookmarkChangeOnlyInBookmarksMode() async throws {
        let model = WordListModel(library: library, settings: settings)
        model.topic = .bookmarks
        await model.load()
        #expect(model.entries.isEmpty)

        try await library.setBookmark(true, id: 101, title: "АВВА")
        await model.bookmarksChanged()
        #expect(model.entries.map(\.id) == [101])

        model.topic = .all
        await model.load()
        let entries = model.entries
        try await library.setBookmark(true, id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        await model.bookmarksChanged()
        #expect(model.entries == entries)
    }
}
