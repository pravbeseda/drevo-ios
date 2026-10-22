import DrevoKit
import Foundation

/// drevo-db's reference build, copied into `Fixtures/` (see its README).
enum Fixtures {
    static func url(_ path: String) -> URL {
        Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil)!
    }

    static func patch() throws -> SQLiteDatabase {
        try SQLiteDatabase(readOnlyAt: url("patch.sqlite"))
    }

    static func main() throws -> SQLiteDatabase {
        try SQLiteDatabase(readOnlyAt: url("main.sqlite"))
    }

    static func expectedText(_ id: Int) throws -> String {
        try String(contentsOf: url("expected/\(id).txt"), encoding: .utf8)
    }

    /// The ids of every article in the fixture index, read from it, so that an article added in drevo-db is tested too.
    static let articleIDs: [Int] = {
        let statement = try! patch().prepare("SELECT _id FROM tblSlovnik ORDER BY _id")
        var ids: [Int] = []
        while try! statement.step() { ids.append(statement.int(at: 0)) }
        return ids
    }()
}
