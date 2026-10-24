import Foundation
import Testing

@testable import DrevoKit

/// Runs word list queries against the fixture index: 105 is a service article (topic 14 only), 102 and 104 are persons.
struct WordListTests {
    private func load(
        _ topic: Topic = .all, search: String = "", settings: ListSettings = ListSettings(),
        bookmarks: SQLiteDatabase? = nil
    ) throws -> [WordEntry] {
        let reader = WordListReader(patch: try Fixtures.patch(), bookmarks: try bookmarks ?? Fixtures.patch())
        return try reader.load(WordListQuery(topic: topic, search: search, settings: settings))
    }

    private func ids(
        _ topic: Topic = .all, search: String = "", settings: ListSettings = ListSettings()
    ) throws -> [Int] {
        try load(topic, search: search, settings: settings).map(\.id)
    }

    @Test func allArticlesStartWithTheMainPageAndAreSortedByTitle() throws {
        let entries = try load()
        #expect(entries.first == WordEntry(id: 4, title: "ГЛАВНАЯ СТРАНИЦА"))
        #expect(entries.map(\.id) == [4, 101, 104, 106, 103, 102])
    }

    @Test func topicRestrictsTheList() throws {
        #expect(try ids(.persons) == [104, 102])
    }

    @Test func serviceArticlesAppearOnlyWhileSearchingByDefault() throws {
        #expect(try !ids().contains(105))
        #expect(try ids(search: "О ПРО") == [105])
    }

    @Test func serviceArticlesCanAlwaysShowOrNever() throws {
        #expect(try ids(settings: ListSettings(serviceArticles: .always)).contains(105))
        #expect(try ids(search: "О ПРО", settings: ListSettings(serviceArticles: .never)).isEmpty)
    }

    @Test func searchMatchesAnywhereByDefaultOrAtTheStart() throws {
        #expect(try ids(search: "РАД") == [102])
        #expect(try ids(search: "РАД", settings: ListSettings(searchMatch: .prefix)).isEmpty)
        #expect(try ids(search: "СЕР", settings: ListSettings(searchMatch: .prefix)) == [102])
    }

    @Test func searchIsUpperCased() throws {
        #expect(try ids(search: "сергий") == [102])
    }

    @Test(arguments: ["%", "_", "'", "\\"])
    func searchCharactersAreTakenLiterally(search: String) throws {
        #expect(try ids(search: search).isEmpty)
    }

    @Test func bookmarksAreReadFromTheBookmarksDatabase() throws {
        let store = try BookmarksStore(at: scratchURL())
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        try store.add(id: 101, title: "АВВА")

        #expect(try load(.bookmarks, bookmarks: store.database).map(\.id) == [101, 102])
        #expect(try load(.bookmarks, search: "сер", bookmarks: store.database).map(\.id) == [102])
    }

    private func scratchURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
    }
}
