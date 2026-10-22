import Foundation
import Testing

@testable import DrevoKit

struct ArticleHistoryTests {
    private func page(_ id: Int, _ anchor: String? = nil, scroll: Double = 0) -> ArticleHistory.Page {
        ArticleHistory.Page(articleID: id, anchor: anchor, scroll: scroll)
    }

    @Test func aNewHistoryIsEmpty() {
        let history = ArticleHistory()
        #expect(history.current == nil)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test func openingAPageMakesItCurrentAtTheTop() {
        var history = ArticleHistory()
        history.open(102)
        #expect(history.current == page(102))
        #expect(!history.canGoBack)
    }

    @Test func goingBackReturnsToTheScrollItWasLeftAt() {
        var history = ArticleHistory()
        history.open(101)
        history.recordScroll(0.4)
        history.open(102)

        #expect(history.goBack() == page(101, scroll: 0.4))
        #expect(history.current == page(101, scroll: 0.4))
        #expect(history.canGoForward)
    }

    @Test func goingForwardReturnsToTheScrollItWasLeftAt() {
        var history = ArticleHistory()
        history.open(101)
        history.open(102)
        history.recordScroll(0.7)
        _ = history.goBack()

        #expect(history.goForward() == page(102, scroll: 0.7))
        #expect(!history.canGoForward)
        #expect(history.canGoBack)
    }

    @Test func openingAPageDropsTheForwardPages() {
        var history = ArticleHistory()
        history.open(101)
        history.open(102)
        _ = history.goBack()
        history.open(103)

        #expect(!history.canGoForward)
        #expect(history.goBack() == page(101))
    }

    @Test func reopeningTheCurrentPageAddsNothing() {
        var history = ArticleHistory()
        history.open(101)
        history.open(101)
        #expect(!history.canGoBack)
    }

    @Test func anAnchorMakesADistinctPage() {
        var history = ArticleHistory()
        history.open(101)
        history.open(101, anchor: "t2")
        #expect(history.current == page(101, "t2"))
        #expect(history.goBack() == page(101))
    }

    @Test func goingPastEitherEndDoesNothing() {
        var history = ArticleHistory()
        history.open(101)
        #expect(history.goBack() == nil)
        #expect(history.goForward() == nil)
        #expect(history.current == page(101))
    }

    @Test func survivesEncoding() throws {
        var history = ArticleHistory()
        history.open(101)
        history.recordScroll(0.25)
        history.open(102, anchor: "t1")
        _ = history.goBack()

        let decoded = try JSONDecoder().decode(ArticleHistory.self, from: JSONEncoder().encode(history))
        #expect(decoded == history)
    }
}
