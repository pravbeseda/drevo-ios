import Foundation

/// A bookmarks file written by a newer version of the app.
public struct UnsupportedBookmarks: Error, Equatable {
    public let userVersion: Int
}

/// The bookmarks file's shape, shared with drevo-android's `bookmarks2.db`: a `tblSlovnik(_id, title)` table that
/// mirrors the patch index, so the word list runs the same query over both, and a file moves between the two apps.
enum BookmarksSchema {
    static let version = 2

    /// Whether a file, such as one being imported, is a bookmarks file this app can open.
    static func accepts(_ database: SQLiteDatabase) throws -> Bool {
        guard (1...version).contains(try database.userVersion()) else { return false }
        let info = try database.prepare("PRAGMA table_info(tblSlovnik)")
        var types: [String: String] = [:]
        while try info.step() {
            types[info.text(at: 1) ?? ""] = info.text(at: 2)?.uppercased()
        }
        return types["_id"] == "INTEGER" && types["title"] == "TEXT"
    }
}

/// The user's bookmarks, in a writable SQLite file of their own.
public struct BookmarksStore {
    let database: SQLiteDatabase

    /// Opens the file, creating it and its table when it is new.
    public init(at url: URL) throws {
        database = try SQLiteDatabase(writableAt: url)
        let version = try database.userVersion()
        if version == 0 {
            try database.execute(
                """
                CREATE TABLE tblSlovnik(_id INTEGER PRIMARY KEY, title TEXT UNIQUE);
                PRAGMA user_version = \(BookmarksSchema.version);
                """)
        } else if version > BookmarksSchema.version {
            throw UnsupportedBookmarks(userVersion: version)
        }
    }

    public func add(id: Int, title: String) throws {
        try run("INSERT OR REPLACE INTO tblSlovnik(_id, title) VALUES (?, ?)", id: id, title: title)
    }

    /// Matches by id or by title, as drevo-android does, so a bookmark outlives its article's id changing.
    public func remove(id: Int, title: String) throws {
        try run("DELETE FROM tblSlovnik WHERE _id = ? OR title = ?", id: id, title: title)
    }

    public func contains(id: Int, title: String) throws -> Bool {
        try run("SELECT 1 FROM tblSlovnik WHERE _id = ? OR title = ? LIMIT 1", id: id, title: title)
    }

    @discardableResult
    private func run(_ sql: String, id: Int, title: String) throws -> Bool {
        let statement = try database.prepare(sql)
        try statement.bind(id, at: 1)
        try statement.bind(title, at: 2)
        return try statement.step()
    }
}
