import Foundation
import SQLite3

/// A failed SQLite call, with the message SQLite gave for it.
public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String

    public var description: String { "SQLite error \(code): \(message)" }
}

/// One connection to an SQLite file. Use it from one task at a time.
public final class SQLiteDatabase {
    fileprivate let handle: OpaquePointer

    /// Opens a file nothing writes while it is open, such as a bundled database: `immutable=1` skips all locking.
    public convenience init(readOnlyAt url: URL) throws {
        try self.init(path: url.absoluteString + "?immutable=1", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI)
    }

    /// Opens the file for reading and writing, creating it when it does not exist.
    public convenience init(writableAt url: URL) throws {
        try self.init(path: url.path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
    }

    private init(path: String, flags: Int32) throws {
        var handle: OpaquePointer?
        let code = sqlite3_open_v2(path, &handle, flags, nil)
        guard code == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(path)"
            sqlite3_close_v2(handle)
            throw SQLiteError(code: code, message: message)
        }
        self.handle = handle
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    public func prepare(_ sql: String) throws -> Statement {
        try Statement(database: self, sql: sql)
    }

    /// Runs statements that return no rows.
    public func execute(_ sql: String) throws {
        try check(sqlite3_exec(handle, sql, nil, nil, nil))
    }

    public func userVersion() throws -> Int {
        let statement = try prepare("PRAGMA user_version")
        _ = try statement.step()
        return statement.int(at: 0)
    }

    fileprivate func check(_ code: Int32) throws {
        guard code == SQLITE_OK else {
            throw SQLiteError(code: code, message: String(cString: sqlite3_errmsg(handle)))
        }
    }
}

/// A prepared statement. Parameter and column indexes follow SQLite: parameters from 1, columns from 0.
public final class Statement {
    // Keeps the connection open for as long as the statement lives.
    private let database: SQLiteDatabase
    private let handle: OpaquePointer

    fileprivate init(database: SQLiteDatabase, sql: String) throws {
        var handle: OpaquePointer?
        try database.check(sqlite3_prepare_v2(database.handle, sql, -1, &handle, nil))
        self.database = database
        self.handle = handle!
    }

    deinit {
        sqlite3_finalize(handle)
    }

    public func bind(_ value: Int, at index: Int32) throws {
        try database.check(sqlite3_bind_int64(handle, index, Int64(value)))
    }

    public func bind(_ value: String, at index: Int32) throws {
        try database.check(sqlite3_bind_text(handle, index, value, -1, transient))
    }

    public func bind(_ value: Data, at index: Int32) throws {
        try value.withUnsafeBytes { bytes in
            try database.check(sqlite3_bind_blob(handle, index, bytes.baseAddress, Int32(bytes.count), transient))
        }
    }

    /// Advances to the next row: `true` while there is one, `false` once the statement is done.
    public func step() throws -> Bool {
        switch sqlite3_step(handle) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        case let code: throw SQLiteError(code: code, message: String(cString: sqlite3_errmsg(database.handle)))
        }
    }

    /// Rewinds the statement and clears its parameters, so it can run again.
    public func reset() throws {
        try database.check(sqlite3_reset(handle))
        try database.check(sqlite3_clear_bindings(handle))
    }

    public func int(at column: Int32) -> Int {
        Int(sqlite3_column_int64(handle, column))
    }

    public func text(at column: Int32) -> String? {
        guard let bytes = sqlite3_column_text(handle, column) else { return nil }
        let count = Int(sqlite3_column_bytes(handle, column))
        return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
    }

    public func blob(at column: Int32) -> Data? {
        guard sqlite3_column_type(handle, column) != SQLITE_NULL else { return nil }
        guard let bytes = sqlite3_column_blob(handle, column) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(handle, column)))
    }
}

/// SQLite copies the bound value before the call returns.
private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
