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

    /// The ids of every article in the fixture index.
    static let articleIDs = [4, 101, 102, 103, 104, 105, 106]
}
