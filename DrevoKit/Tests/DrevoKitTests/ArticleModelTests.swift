import Foundation
import Testing

@testable import DrevoKit

@MainActor
struct ArticleModelTests {
    private let base = URL(fileURLWithPath: "/private/var/Drevo.app/", isDirectory: true)
    private let bookmarksURL = Fixtures.scratchURL()
    private let library: Library
    private let model: ArticleModel

    init() throws {
        library = try Fixtures.library(bookmarks: bookmarksURL)
        model = ArticleModel(library: library, baseURL: base, timeZone: TimeZone(identifier: "Europe/Moscow")!)
    }

    private func url(_ href: String) -> URL {
        URL(string: href, relativeTo: base)!.absoluteURL
    }

    @Test func selectingAnArticleShowsItAndItsContents() async {
        await model.select(102)
        #expect(model.selection == 102)
        #expect(model.page?.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(model.page?.html.contains("Преподобный Сергий Радонежский") == true)
        #expect(model.contents.count == 5)
        #expect(model.failure == nil)
    }

    @Test func startShowsTheMainPageWithoutSelectingIt() async {
        await model.start()
        #expect(model.page?.title == "ГЛАВНАЯ СТРАНИЦА")
        #expect(model.selection == nil)
    }

    @Test func clearingTheSelectionKeepsThePage() async {
        await model.select(102)
        await model.select(nil)
        #expect(model.selection == nil)
        #expect(model.page?.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
    }

    @Test func anArticleLinkOpensItAsANewStep() async {
        await model.select(102)
        #expect(await model.decide(url("101")) == .cancel)
        #expect(model.page?.title == "АВВА")
        #expect(model.selection == 101)
        #expect(model.history.canGoBack)
    }

    @Test func anArticleLinkWithAnAnchorOpensAtIt() async {
        await model.select(101)
        _ = await model.decide(url("102#t2"))
        #expect(model.page?.opensAtAnchor == true)
    }

    @Test func otherLinksAreLeftToTheWebViewOrTheSystem() async {
        #expect(await model.decide(url("#t1")) == .allow)
        #expect(
            await model.decide(URL(string: "https://drevo-info.ru")!)
                == .openExternally(URL(string: "https://drevo-info.ru")!))
        #expect(await model.decide(url("picture.jpg")) == .cancel)
    }

    @Test func backAndForwardRestoreTheScroll() async {
        await model.select(101)
        model.recordScroll(0.5, onPage: model.pageID)
        await model.select(102)

        await model.goBack()
        #expect(model.page?.title == "АВВА")
        #expect(model.page?.html.contains("window.scrollTo(0, 0.5 * ") == true)
        #expect(model.selection == 101)

        await model.goForward()
        #expect(model.page?.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
    }

    @Test func aNewWebViewResumesThePageWhereItWasLeft() async {
        await model.select(101)
        model.recordScroll(0.5, onPage: model.pageID)
        #expect(model.page?.html.contains("window.scrollTo") == false)
        #expect(model.resumedPage()?.html.contains("window.scrollTo(0, 0.5 * ") == true)
        #expect(model.resumedPage()?.title == "АВВА")
    }

    @Test func aFailedPageHasNothingToResume() async {
        await model.select(999)
        #expect(model.resumedPage() == nil)
    }

    @Test func togglingTheBookmarkStoresItAndReports() async throws {
        var changes = 0
        model.onBookmarksChanged = { changes += 1 }
        await model.select(102)
        #expect(!model.isBookmarked)

        await model.toggleBookmark()
        #expect(model.isBookmarked)
        #expect(try await library.isBookmarked(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))

        await model.toggleBookmark()
        #expect(!model.isBookmarked)
        #expect(changes == 2)
    }

    @Test func anUnknownArticleIsAFailure() async {
        await model.select(999)
        #expect(model.failure == .notFound)
        #expect(model.page == nil)
    }

    @Test func aSpecialArticleOpensByItsId() async {
        await model.open(.mainPage)
        #expect(model.selection == 4)
        #expect(model.page?.title == "ГЛАВНАЯ СТРАНИЦА")
    }

    @Test func aDayWithoutItsArticleIsAFailure() async {
        // The fixtures hold no calendar days.
        await model.openToday()
        #expect(model.failure == .noArticleForDay)
    }

    @Test func aSavedHistoryShowsItsPageAtItsScroll() async throws {
        await model.select(103)
        model.recordScroll(0.25, onPage: model.pageID)
        let saved = try #require(model.savedHistory())

        let next = ArticleModel(library: library, baseURL: base)
        await next.start(restoring: saved, selecting: false)
        #expect(next.page?.title == "ПАТЕРИК")
        #expect(next.page?.html.contains("window.scrollTo(0, 0.25 * ") == true)
        #expect(next.history == model.history)
        #expect(next.selection == nil)
    }

    @Test func aHistorySavedWithItsArticleOnScreenSelectsIt() async throws {
        await model.select(103)
        let saved = try #require(model.savedHistory())
        let next = ArticleModel(library: library, baseURL: base)
        await next.start(restoring: saved, selecting: true)
        #expect(next.selection == 103)
    }

    @Test func anUnreadableSavedHistoryStartsAtTheMainPage() async {
        await model.start(restoring: Data("not json".utf8), selecting: true)
        #expect(model.page?.title == "ГЛАВНАЯ СТРАНИЦА")
        #expect(model.selection == nil)
    }

    @Test func startingAgainKeepsWhatIsShown() async throws {
        await model.select(103)
        let saved = try #require(model.savedHistory())
        await model.select(102)
        await model.start(restoring: saved, selecting: true)
        #expect(model.page?.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
    }

    @Test func aScrollFromAPageNoLongerShownIsIgnored() async {
        await model.select(101)
        let leaving = model.pageID
        await model.select(102)
        // The old page's web view may report once more after the next one was opened.
        model.recordScroll(0.9, onPage: leaving)

        await model.goBack()
        await model.goForward()
        #expect(model.page?.html.contains("window.scrollTo") == false)
    }

    @Test func aScrollFromAnEarlierShowingOfTheSamePageIsIgnored() async {
        await model.select(101)
        let first = model.pageID
        await model.select(102)
        await model.select(101)
        model.recordScroll(0.9, onPage: first)

        await model.goBack()
        await model.goForward()
        #expect(model.page?.html.contains("window.scrollTo") == false)
    }

    @Test func everyPageShownGetsItsOwnID() async {
        var ids: [Int] = []
        await model.select(101)
        ids.append(model.pageID)
        await model.select(102)
        ids.append(model.pageID)
        await model.goBack()
        ids.append(model.pageID)
        await model.goForward()
        ids.append(model.pageID)
        #expect(Set(ids).count == ids.count)
    }

    @Test func thePageIDChangesWithThePage() async {
        await model.select(101)
        let first = model.pageID
        await model.select(102)
        #expect(model.pageID != first)
        #expect(model.page?.title == "СЕРГИЙ РАДОНЕЖСКИЙ")
        await model.select(999)
        #expect(model.page == nil)
    }

    @Test func manyQuickBookmarkTapsEndWhereTheFileDoes() async throws {
        await model.select(102)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 { group.addTask { await model.toggleBookmark() } }
        }
        let stored = try await library.isBookmarked(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ")
        #expect(stored)
        #expect(model.isBookmarked == stored)
    }

    @Test func aTapBookmarksTheArticleItWasMadeOnEvenAfterAnotherOpens() async throws {
        await model.select(102)
        async let tap: Void = model.toggleBookmark()
        await model.select(101)
        await tap

        #expect(try await library.isBookmarked(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        #expect(try await !library.isBookmarked(id: 101, title: "АВВА"))
        #expect(!model.isBookmarked)
    }

    @Test func twoQuickBookmarkTapsAddAndRemove() async throws {
        await model.select(102)
        async let first: Void = model.toggleBookmark()
        async let second: Void = model.toggleBookmark()
        _ = await (first, second)

        #expect(try await !library.isBookmarked(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ"))
        #expect(!model.isBookmarked)
    }

    @Test func aBookmarkFailureLastsUntilDismissedOrAnotherPage() async throws {
        await model.select(102)
        try SQLiteDatabase(writableAt: bookmarksURL).execute("DROP TABLE tblSlovnik")
        await model.toggleBookmark()
        #expect(model.bookmarkFailed)

        model.dismissBookmarkFailure()
        #expect(!model.bookmarkFailed)

        await model.toggleBookmark()
        await model.select(101)
        #expect(!model.bookmarkFailed)
    }

    @Test func aFailedPageIsNotBookmarked() async {
        await model.select(102)
        await model.toggleBookmark()
        await model.select(999)
        #expect(!model.isBookmarked)
    }
}
