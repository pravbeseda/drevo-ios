import Testing

@testable import DrevoKit

struct ArticleReaderTests {
    private func read(_ id: Int) throws -> ArticleRows? {
        try ArticleReader(patch: Fixtures.patch(), main: Fixtures.main()).read(id: id)
    }

    @Test func deltaIsReadWithItsBase() throws {
        let rows = try #require(try read(102))
        #expect(rows.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(rows.patchBlob != nil)
        #expect(rows.mainBlob != nil)
        #expect(!rows.patchIsFullText)
    }

    @Test func fullTextSkipsTheMainDatabase() throws {
        // 103 still has a row in main; a full-text patch makes it irrelevant.
        let rows = try #require(try read(103))
        #expect(rows.patchBlob != nil)
        #expect(rows.mainBlob == nil)
        #expect(rows.patchIsFullText)
    }

    @Test func articleWithoutPatchRowIsReadFromMain() throws {
        let rows = try #require(try read(101))
        #expect(rows.patchBlob == nil)
        #expect(rows.mainBlob != nil)
    }

    @Test func articleNewInThePatchHasNoMainRow() throws {
        let rows = try #require(try read(106))
        #expect(rows.patchIsFullText)
        #expect(rows.mainBlob == nil)
    }

    // The main page's title carries a leading space in every database published so far (format.md, version 0).
    @Test func titleIsTrimmed() throws {
        #expect(try read(4)?.title == "ГЛАВНАЯ СТРАНИЦА")
    }

    @Test func unknownIDIsNil() throws {
        #expect(try read(999) == nil)
    }
}
