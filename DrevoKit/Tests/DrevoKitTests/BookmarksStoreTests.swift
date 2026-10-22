import Foundation
import Testing

@testable import DrevoKit

struct BookmarksStoreTests {
    private func scratchURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
    }

    @Test func aNewStoreHasTheTableAndVersionDrevoAndroidWrites() throws {
        let store = try BookmarksStore(at: scratchURL())
        #expect(try store.database.userVersion() == BookmarksSchema.version)
        #expect(try BookmarksSchema.accepts(store.database))
    }

    @Test func addedBookmarksAreFoundByIDOrTitleAndRemoved() throws {
        let store = try BookmarksStore(at: scratchURL())
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")

        #expect(try store.contains(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        // drevo-android matches either, so a bookmark survives its article's id changing between databases.
        #expect(try store.contains(id: 999, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        #expect(try !store.contains(id: 101, title: "АВВА"))

        try store.remove(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(try !store.contains(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
    }

    @Test func addingTwiceKeepsOneBookmark() throws {
        let store = try BookmarksStore(at: scratchURL())
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")

        let count = try store.database.prepare("SELECT count(*) FROM tblSlovnik")
        _ = try count.step()
        #expect(count.int(at: 0) == 1)
    }

    @Test func bookmarksSurviveReopening() throws {
        let url = scratchURL()
        try BookmarksStore(at: url).add(id: 101, title: "АВВА")
        #expect(try BookmarksStore(at: url).contains(id: 101, title: "АВВА"))
    }

    @Test func aFileFromANewerAppVersionIsRefused() throws {
        let url = scratchURL()
        try SQLiteDatabase(writableAt: url).execute("PRAGMA user_version = 3")
        #expect(throws: UnsupportedBookmarks.self) { try BookmarksStore(at: url) }
    }
}

struct BookmarksSchemaTests {
    private func database(userVersion: Int, table: String?) throws -> SQLiteDatabase {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let database = try SQLiteDatabase(writableAt: url)
        if let table { try database.execute("CREATE TABLE tblSlovnik(\(table))") }
        try database.execute("PRAGMA user_version = \(userVersion)")
        return database
    }

    @Test(arguments: [1, 2])
    func acceptsEveryVersionDrevoAndroidWrote(userVersion: Int) throws {
        #expect(try BookmarksSchema.accepts(database(userVersion: userVersion, table: "_id INTEGER, title TEXT")))
    }

    @Test func typesAreComparedIgnoringCase() throws {
        #expect(try BookmarksSchema.accepts(database(userVersion: 2, table: "_id integer PRIMARY KEY, title text")))
    }

    @Test(arguments: [
        (0, "_id INTEGER, title TEXT"), (3, "_id INTEGER, title TEXT"), (2, "_id INTEGER"), (2, "title TEXT"),
        (2, "_id TEXT, title TEXT"), (2, "_id INTEGER, title BLOB"),
    ])
    func refusesAnythingElse(userVersion: Int, table: String) throws {
        #expect(try !BookmarksSchema.accepts(database(userVersion: userVersion, table: table)))
    }

    @Test func refusesAFileWithoutTheTable() throws {
        #expect(try !BookmarksSchema.accepts(database(userVersion: 2, table: nil)))
    }
}
