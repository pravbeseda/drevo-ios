import Foundation
import Testing

@testable import DrevoKit

/// The release gate format.md asks for: the databases `db.lock` pins must be in a format this client reads, and every
/// article must assemble. Runs only when `DREVO_DATABASE_DIR` names the fetched databases, as CI does after fetching.
@Suite(.enabled(if: databaseDirectory != nil, "set DREVO_DATABASE_DIR to Drevo/Resources/Database"))
struct BundledDatabaseTests {
    private func open(_ name: String) throws -> SQLiteDatabase {
        try SQLiteDatabase(readOnlyAt: #require(databaseDirectory).appendingPathComponent(name))
    }

    @Test func formatIsOneThisClientReads() throws {
        try FormatVersion.check(open("patch.sqlite"))
        try FormatVersion.check(open("main.sqlite"))
    }

    @Test func everyArticleAssembles() throws {
        let patch = try open("patch.sqlite")
        let reader = ArticleReader(patch: patch, main: try open("main.sqlite"))
        let ids = try patch.prepare("SELECT _id FROM tblSlovnik")
        var count = 0
        var failures: [String] = []
        while try ids.step() {
            let id = ids.int(at: 0)
            count += 1
            do {
                let rows = try #require(try reader.read(id: id))
                _ = try ArticleAssembler.assemble(
                    patch: rows.patchBlob, main: rows.mainBlob, patchIsFullText: rows.patchIsFullText)
            } catch {
                failures.append("\(id): \(error)")
            }
        }
        #expect(count > 0)
        #expect(failures.isEmpty, "\(failures.count) of \(count) articles fail, first: \(failures.prefix(5))")
    }
}

private let databaseDirectory = ProcessInfo.processInfo.environment["DREVO_DATABASE_DIR"].map {
    URL(fileURLWithPath: $0)
}
