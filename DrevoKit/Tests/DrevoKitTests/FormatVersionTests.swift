import Foundation
import Testing

@testable import DrevoKit

struct FormatVersionTests {
    private func database(userVersion: Int) throws -> SQLiteDatabase {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let database = try SQLiteDatabase(writableAt: url)
        try database.execute("PRAGMA user_version = \(userVersion)")
        return database
    }

    @Test(arguments: [0, 1])
    func readsEveryPublishedFormat(userVersion: Int) throws {
        try FormatVersion.check(database(userVersion: userVersion))
    }

    @Test func refusesANewerFormat() throws {
        let database = try database(userVersion: 2)
        #expect(throws: UnsupportedFormat(userVersion: 2)) { try FormatVersion.check(database) }
    }

    @Test func acceptsTheFixtures() throws {
        try FormatVersion.check(Fixtures.patch())
        try FormatVersion.check(Fixtures.main())
    }
}
