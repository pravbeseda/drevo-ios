import Foundation
import Observation

/// The articles of format.md's "Special articles", reached from the "⋯" menu.
public enum SpecialArticle: Int, CaseIterable, Sendable {
    case aboutSite = 1
    case calendar = 2
    case chronology = 3
    case mainPage = 4
}

/// What the web view does with a link it is about to follow.
public enum LinkDecision: Equatable, Sendable {
    case allow
    case cancel
    case openExternally(URL)
}

/// The article column: the page on screen, its history, and the word list selection that shows it.
@MainActor
@Observable
public final class ArticleModel {
    public enum Failure: Equatable, Sendable {
        case notFound
        case corrupt
        case unreadable
        case noArticleForDay
    }

    /// The word list's selection. On a compact width a non-nil selection pushes the article and clearing it pops
    /// back, so it changes only when the user asks for an article, never by itself.
    public private(set) var selection: Int?
    public private(set) var page: ArticlePage?
    /// Changes with every page opened, including reopening the same one; the web view loads `page` when it
    /// changes and reports scrolls with the id it loaded.
    public private(set) var pageID = 0
    public private(set) var contents: [TocEntry] = []
    public private(set) var isBookmarked = false
    public private(set) var bookmarkFailed = false
    public private(set) var failure: Failure?
    public private(set) var history = ArticleHistory()

    /// The bundle directory the page is loaded from, where its stylesheets and scripts are.
    public let baseURL: URL
    @ObservationIgnored public var onBookmarksChanged: (@MainActor () -> Void)?

    @ObservationIgnored private let library: Library
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private var shown: Article?
    @ObservationIgnored private var bookmarkRequests = 0

    public init(library: Library, baseURL: URL, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current) {
        self.library = library
        self.baseURL = baseURL
        self.now = now
        self.timeZone = timeZone
    }

    /// Shows the main page when nothing else is shown yet, without selecting it.
    public func start() async {
        guard history.current == nil else { return }
        history.open(SpecialArticle.mainPage.rawValue)
        await show()
    }

    /// The word list's selection changed; `nil` keeps the page for when the article column is visible again.
    public func select(_ id: Int?) async {
        guard let id else {
            selection = nil
            return
        }
        await openStep(id, anchor: nil)
    }

    public func open(_ special: SpecialArticle) async {
        await openStep(special.rawValue, anchor: nil)
    }

    public func openToday() async {
        await openDay(DayTitle.today(at: now(), in: timeZone))
    }

    public func openTomorrow() async {
        await openDay(DayTitle.tomorrow(at: now(), in: timeZone))
    }

    public func decide(_ url: URL) async -> LinkDecision {
        switch ArticleLink(url: url, base: baseURL) {
        case .article(let id, let anchor):
            await openStep(id, anchor: anchor)
            return .cancel
        case .samePage:
            return .allow
        case .external(let url):
            return .openExternally(url)
        case .ignored:
            return .cancel
        }
    }

    public func goBack() async {
        guard history.goBack() != nil else { return }
        selection = history.current?.articleID
        await show()
    }

    public func goForward() async {
        guard history.goForward() != nil else { return }
        selection = history.current?.articleID
        await show()
    }

    /// A page reported how far it is scrolled, as a fraction of its height. The previous page's web view can still
    /// report while the next page loads or after, so only reports carrying the current `pageID` count.
    public func recordScroll(_ position: Double, onPage id: Int) {
        guard id == pageID, page != nil else { return }
        history.recordScroll(position)
    }

    /// Shows a history saved with the scene; `selecting` restores an article column that was on screen.
    public func restore(_ history: ArticleHistory, selecting: Bool) async {
        self.history = history
        selection = selecting ? history.current?.articleID : nil
        await show()
    }

    public func toggleBookmark() async {
        guard let article = shown else { return }
        bookmarkRequests += 1
        let request = bookmarkRequests
        do {
            let isOn = try await library.toggleBookmark(id: article.id, title: article.title)
            onBookmarksChanged?()
            // A later tap, or another page, may have come in while this one was written; the latest one decides.
            guard request == bookmarkRequests, article == shown else { return }
            isBookmarked = isOn
            bookmarkFailed = false
        } catch {
            if request == bookmarkRequests, article == shown { bookmarkFailed = true }
        }
    }

    /// The view has shown the bookmark failure.
    public func dismissBookmarkFailure() {
        bookmarkFailed = false
    }

    private func openStep(_ id: Int, anchor: String?) async {
        history.open(id, anchor: anchor)
        selection = id
        await show()
    }

    private func openDay(_ title: String) async {
        do {
            guard let id = try await library.id(forTitle: title) else {
                fail(.noArticleForDay)
                return
            }
            await openStep(id, anchor: nil)
        } catch {
            fail(.unreadable)
        }
    }

    private func show() async {
        guard let target = history.current else { return }
        pageID += 1
        let id = pageID
        let article: Article?
        var bookmarked = false
        do {
            article = try await library.article(target.articleID)
            if let article { bookmarked = try await library.isBookmarked(id: article.id, title: article.title) }
        } catch {
            if id == pageID { fail(error is CorruptArticle ? .corrupt : .unreadable) }
            return
        }
        // Another page may have been opened while this one loaded.
        guard id == pageID else { return }
        guard let article else {
            fail(.notFound)
            return
        }
        let builder = ArticleHtmlBuilder(today: now(), timeZone: timeZone)
        page = builder.build(title: article.title, body: article.body, anchor: target.anchor, scroll: target.scroll)
        contents = article.contents
        isBookmarked = bookmarked
        bookmarkFailed = false
        shown = article
        failure = nil
    }

    private func fail(_ failure: Failure) {
        self.failure = failure
        page = nil
        contents = []
        isBookmarked = false
        bookmarkFailed = false
        shown = nil
    }
}
