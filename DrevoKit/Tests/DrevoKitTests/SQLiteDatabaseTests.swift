import Foundation
import Testing

@testable import DrevoKit

struct SQLiteDatabaseTests {
    private func patch() throws -> SQLiteDatabase {
        try Fixtures.patch()
    }

    private func scratchURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
    }

    @Test func readsTextAndIntegerColumnsWithBoundParameters() throws {
        let statement = try patch().prepare("SELECT _id, title FROM tblSlovnik WHERE _id = ?")
        try statement.bind(102, at: 1)

        #expect(try statement.step())
        #expect(statement.int(at: 0) == 102)
        #expect(statement.text(at: 1) == "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(try !statement.step())
    }

    @Test func readsBlobsAndNulls() throws {
        let statement = try patch().prepare("SELECT ziptext, NULL FROM tblTexts WHERE _id = 103")

        #expect(try statement.step())
        #expect(statement.blob(at: 0)?.count == 152)
        #expect(statement.blob(at: 1) == nil)
        #expect(statement.text(at: 1) == nil)
    }

    @Test func bindsTextAndCanBeReusedAfterReset() throws {
        let statement = try patch().prepare("SELECT _id FROM tblSlovnik WHERE title = ?")
        try statement.bind("АВВА", at: 1)
        #expect(try statement.step())
        #expect(statement.int(at: 0) == 101)

        try statement.reset()
        try statement.bind("ЛАВРА", at: 1)
        #expect(try statement.step())
        #expect(statement.int(at: 0) == 106)
    }

    @Test func readsUserVersion() throws {
        #expect(try patch().userVersion() == 1)
    }

    @Test func readOnlyPathMayHoldSpacesAndCyrillic() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Древо \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("patch #1.sqlite")
        try FileManager.default.copyItem(at: Fixtures.url("patch.sqlite"), to: url)

        #expect(try SQLiteDatabase(readOnlyAt: url).userVersion() == 1)
    }

    @Test func readOnlyDatabaseRefusesWrites() throws {
        #expect(throws: SQLiteError.self) { try patch().execute("DELETE FROM tblSlovnik") }
    }

    @Test func missingFileIsAnError() {
        #expect(throws: SQLiteError.self) {
            try SQLiteDatabase(readOnlyAt: URL(fileURLWithPath: "/nonexistent/patch.sqlite"))
        }
    }

    @Test func invalidSQLReportsSQLiteMessage() throws {
        let error = #expect(throws: SQLiteError.self) { try patch().prepare("SELECT FROM") }
        #expect(error?.message.contains("syntax error") == true)
    }

    // SQLite prepares these without error but returns no statement.
    @Test(arguments: ["", "  ", "-- nothing to run"])
    func sqlWithoutAStatementIsAnError(sql: String) throws {
        let database = try patch()
        #expect(throws: SQLiteError.self) { try database.prepare(sql) }
    }

    @Test func writableDatabaseIsCreatedAndKeepsWhatIsWritten() throws {
        let url = scratchURL()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let database = try SQLiteDatabase(writableAt: url)
            try database.execute("CREATE TABLE t(id INTEGER, data BLOB)")
            let insert = try database.prepare("INSERT INTO t VALUES (?, ?)")
            try insert.bind(7, at: 1)
            try insert.bind(Data([1, 2, 3]), at: 2)
            #expect(try !insert.step())
        }

        let statement = try SQLiteDatabase(readOnlyAt: url).prepare("SELECT id, data FROM t")
        #expect(try statement.step())
        #expect(statement.int(at: 0) == 7)
        #expect(statement.blob(at: 1) == Data([1, 2, 3]))
    }
}
