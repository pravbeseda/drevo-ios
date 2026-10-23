import Foundation
import Testing

@testable import DrevoKit

struct LibraryTests {
    @Test func readsTheWordList() async throws {
        let library = try Fixtures.library()
        let entries = try await library.words(WordListQuery(topic: .persons, search: "", settings: ListSettings()))
        #expect(entries.map(\.id) == [104, 102])
    }

    @Test func assemblesAnArticleWithItsContents() async throws {
        let article = try #require(try await Fixtures.library().article(102))
        #expect(article.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(article.contents.map(\.anchor) == ["t0", "t1", "t2", "t3", "t4"])
    }

    @Test func anUnknownArticleIsNil() async throws {
        #expect(try await Fixtures.library().article(999) == nil)
    }

    @Test func findsAnArticleByTitle() async throws {
        #expect(try await Fixtures.library().id(forTitle: "ЛАВРА") == 106)
    }

    @Test func keepsBookmarks() async throws {
        let library = try Fixtures.library()
        try await library.setBookmark(true, id: 101, title: "АВВА")
        #expect(try await library.isBookmarked(id: 101, title: "АВВА"))
        let bookmarks = try await library.words(WordListQuery(topic: .bookmarks, search: "", settings: ListSettings()))
        #expect(bookmarks.map(\.id) == [101])

        try await library.setBookmark(false, id: 101, title: "АВВА")
        #expect(try await !library.isBookmarked(id: 101, title: "АВВА"))
    }

    @Test func exportsBookmarksThatAnotherLibraryMerges() async throws {
        let library = try Fixtures.library()
        try await library.setBookmark(true, id: 101, title: "АВВА")
        let file = Fixtures.scratchURL()
        try await library.exportBookmarks(to: file)

        let other = try Fixtures.library()
        #expect(try await other.mergeBookmarks(from: file) == 1)
        #expect(try await other.isBookmarked(id: 101, title: "АВВА"))
    }
}
