import Foundation
import Testing

@testable import DrevoKit

@MainActor
struct BookmarksFileModelTests {
    private let library: Library
    private let model: BookmarksFileModel

    init() throws {
        library = try Fixtures.library()
        // 23 October 2026, 22:30 UTC: already the 24th in Moscow.
        let now = Date(timeIntervalSince1970: 1_792_794_600)
        model = BookmarksFileModel(
            library: library, now: { now }, timeZone: TimeZone(identifier: "Europe/Moscow")!)
    }

    /// A bookmarks file holding the given bookmarks, as another device would export it.
    private func bookmarksFile(_ bookmarks: [(Int, String)]) throws -> URL {
        let url = Fixtures.scratchURL()
        let store = try BookmarksStore(at: url)
        for (id, title) in bookmarks { try store.add(id: id, title: title) }
        return url
    }

    @Test func theExportIsNamedAsDrevoAndroidNamesItWithTheLocalDate() {
        #expect(model.exportFileName == "DrevoBookmarks-20261024.db")
    }

    @Test func theExportHoldsEveryBookmark() async throws {
        try await library.setBookmark(true, id: 101, title: "АВВА")

        let data = try #require(await model.exportedFile())

        let file = Fixtures.scratchURL()
        try data.write(to: file)
        #expect(try BookmarksStore(at: file).contains(id: 101, title: "АВВА"))
        #expect(model.outcome == nil)
    }

    @Test func importingAddsTheFilesBookmarksAndReports() async throws {
        var changes = 0
        model.onBookmarksChanged = { changes += 1 }
        try await library.setBookmark(true, id: 101, title: "АВВА")

        await model.importFile(at: try bookmarksFile([(101, "АВВА"), (102, "СЕРГИЙ РАДОНЕЖСКИЙ")]))

        #expect(model.outcome == .imported(count: 1))
        #expect(try await library.isBookmarked(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        #expect(changes == 1)
    }

    @Test func importingNothingNewChangesNothing() async throws {
        var changes = 0
        model.onBookmarksChanged = { changes += 1 }
        try await library.setBookmark(true, id: 101, title: "АВВА")

        await model.importFile(at: try bookmarksFile([(101, "АВВА")]))

        #expect(model.outcome == .imported(count: 0))
        #expect(changes == 0)
    }

    @Test func importingAnotherDatabaseSaysItIsNoBookmarksFile() async throws {
        let url = Fixtures.scratchURL()
        try SQLiteDatabase(writableAt: url).execute("CREATE TABLE notes(text TEXT); PRAGMA user_version = 2")

        await model.importFile(at: url)

        #expect(model.outcome == .notBookmarks)
    }

    @Test func importingAFileThatIsNoDatabaseFails() async throws {
        let url = Fixtures.scratchURL()
        try Data("not a database".utf8).write(to: url)

        await model.importFile(at: url)

        #expect(model.outcome == .importFailed)
    }

    @Test func theOutcomeIsDismissed() async throws {
        await model.importFile(at: try bookmarksFile([]))
        model.dismissOutcome()
        #expect(model.outcome == nil)
    }
}
