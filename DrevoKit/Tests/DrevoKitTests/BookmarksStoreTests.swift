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

    @Test func anExportIsABookmarksFileWithEveryBookmark() throws {
        let store = try BookmarksStore(at: scratchURL())
        try store.add(id: 101, title: "АВВА")
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        let exported = scratchURL()

        try store.export(to: exported)

        let copy = try SQLiteDatabase(readOnlyAt: exported)
        #expect(try BookmarksSchema.accepts(copy))
        #expect(try copy.userVersion() == BookmarksSchema.version)
        let opened = try BookmarksStore(at: exported)
        #expect(try opened.contains(id: 101, title: "АВВА"))
        #expect(try opened.contains(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
    }

    @Test func mergingAddsTheOtherFilesBookmarksAndKeepsEveryOwnOne() throws {
        let store = try BookmarksStore(at: scratchURL())
        try store.add(id: 101, title: "АВВА")
        try store.add(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        let other = scratchURL()
        let otherStore = try BookmarksStore(at: other)
        try otherStore.add(id: 101, title: "АВВА")
        // The same article under another id, as after the database changed: a bookmark already, so not added.
        try otherStore.add(id: 999, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        try otherStore.add(id: 103, title: "ГЛАВНАЯ СТРАНИЦА")

        #expect(try store.merge(from: other) == 1)

        #expect(try store.contains(id: 101, title: "АВВА"))
        #expect(try store.contains(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        #expect(try store.contains(id: 103, title: "ГЛАВНАЯ СТРАНИЦА"))
        let count = try store.database.prepare("SELECT count(*) FROM tblSlovnik")
        _ = try count.step()
        #expect(count.int(at: 0) == 3)
    }

    @Test func mergingTakesAFileDrevoAndroidWroteAtVersionOne() throws {
        let other = scratchURL()
        let database = try SQLiteDatabase(writableAt: other)
        try database.execute(
            """
            CREATE TABLE tblSlovnik(_id INTEGER PRIMARY KEY, title TEXT);
            INSERT INTO tblSlovnik VALUES (101, 'АВВА');
            PRAGMA user_version = 1;
            """)
        let store = try BookmarksStore(at: scratchURL())

        #expect(try store.merge(from: other) == 1)
        #expect(try store.contains(id: 101, title: "АВВА"))
    }

    @Test(arguments: ["CREATE TABLE notes(text TEXT); PRAGMA user_version = 2", "PRAGMA user_version = 3"])
    func mergingRefusesAFileThatIsNotBookmarks(sql: String) throws {
        let other = scratchURL()
        try SQLiteDatabase(writableAt: other).execute(sql)
        let store = try BookmarksStore(at: scratchURL())

        #expect(throws: NotBookmarks.self) { try store.merge(from: other) }
    }

    @Test func mergingRefusesAFileThatIsNotADatabase() throws {
        let other = scratchURL()
        try Data("not a database".utf8).write(to: other)
        let store = try BookmarksStore(at: scratchURL())

        #expect(throws: (any Error).self) { try store.merge(from: other) }
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
