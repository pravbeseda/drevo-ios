import Testing

@testable import DrevoKit

struct DatabaseLockTests {
    @Test func readsTheRelease() {
        let lock = """
            # The drevo-db release the app bundles.
            DB_RELEASE=db-254-258
            MAIN_RELEASE=db-254-258
            """
        #expect(DatabaseLock.release(in: lock) == "db-254-258")
    }

    @Test func aFileWithoutTheReleaseHasNone() {
        #expect(DatabaseLock.release(in: "# DB_RELEASE=db-1-2\nMAIN_RELEASE=db-1-2") == nil)
    }
}
