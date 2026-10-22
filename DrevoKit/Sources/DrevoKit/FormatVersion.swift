/// A database written in a format newer than this client reads.
public struct UnsupportedFormat: Error, Equatable {
    public let userVersion: Int
}

/// The database formats this client reads: `PRAGMA user_version` 0 and 1 (format.md, "Version").
enum FormatVersion {
    static let newestSupported = 1

    static func check(_ database: SQLiteDatabase) throws {
        let version = try database.userVersion()
        guard version <= newestSupported else { throw UnsupportedFormat(userVersion: version) }
    }
}
