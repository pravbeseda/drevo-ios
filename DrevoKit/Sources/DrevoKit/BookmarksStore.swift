import Foundation

/// A bookmarks file written by a newer version of the app.
public struct UnsupportedBookmarks: Error, Equatable {
    public let userVersion: Int
}

/// A file offered for import that is no bookmarks file this app can read.
public struct NotBookmarks: Error, Equatable {}

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
                // One transaction, so the file never holds the table at version 0, which would fail every reopen.
                """
                BEGIN;
                CREATE TABLE tblSlovnik(_id INTEGER PRIMARY KEY, title TEXT UNIQUE);
                PRAGMA user_version = \(BookmarksSchema.version);
                COMMIT;
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

    /// Writes every bookmark to a new file at `url`, one consistent copy that drevo-android can import too.
    public func export(to url: URL) throws {
        let statement = try database.prepare("VACUUM INTO ?")
        try statement.bind(url.path, at: 1)
        _ = try statement.step()
    }

    /// Adds the bookmarks of the file at `url` and keeps every one this store has: one matching by id or by title
    /// is already here. Returns how many were added.
    public func merge(from url: URL) throws -> Int {
        let other = try SQLiteDatabase(readOnlyAt: url)
        guard try BookmarksSchema.accepts(other) else { throw NotBookmarks() }
        let rows = try other.prepare("SELECT _id, title FROM tblSlovnik WHERE title IS NOT NULL")
        let before = try count()
        try database.execute("BEGIN")
        do {
            let insert = try database.prepare("INSERT OR IGNORE INTO tblSlovnik(_id, title) VALUES (?, ?)")
            while try rows.step() {
                try insert.bind(rows.int(at: 0), at: 1)
                try insert.bind(rows.text(at: 1) ?? "", at: 2)
                _ = try insert.step()
                try insert.reset()
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        return try count() - before
    }

    private func count() throws -> Int {
        let statement = try database.prepare("SELECT count(*) FROM tblSlovnik")
        _ = try statement.step()
        return statement.int(at: 0)
    }

    @discardableResult
    private func run(_ sql: String, id: Int, title: String) throws -> Bool {
        let statement = try database.prepare(sql)
        try statement.bind(id, at: 1)
        try statement.bind(title, at: 2)
        return try statement.step()
    }
}
