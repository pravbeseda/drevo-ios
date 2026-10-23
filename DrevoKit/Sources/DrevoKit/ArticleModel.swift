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
    /// Identifies `page` and changes together with it, reopening the same article included; the web view loads
    /// `page` when it changes and reports scrolls with the id it loaded.
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
    /// Counts the loads started; ahead of `pageID` while one is in flight.
    @ObservationIgnored private var loads = 0
    @ObservationIgnored private var bookmarkTask: Task<Void, Never>?

    public init(library: Library, baseURL: URL, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current) {
        self.library = library
        self.baseURL = baseURL
        self.now = now
        self.timeZone = timeZone
    }

    /// Shows what a window saved with `savedHistory()` had on screen, selecting it when `selecting`, or else the main
    /// page, unselected; nothing once a page is shown, as when a window's view appears again.
    public func start(restoring saved: Data? = nil, selecting: Bool = false) async {
        guard history.current == nil else { return }
        // A history this version cannot read, as from a later one, starts over at the main page.
        if let saved, let restored = try? JSONDecoder().decode(ArticleHistory.self, from: saved),
            let current = restored.current
        {
            history = restored
            selection = selecting ? current.articleID : nil
        } else {
            history.open(SpecialArticle.mainPage.rawValue)
        }
        await show()
    }

    /// The history for a window to keep and hand back to `start(restoring:selecting:)`.
    public func savedHistory() -> Data? {
        try? JSONEncoder().encode(history)
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
    /// report while the next page loads or after, so a report counts only when it carries the current `pageID` and
    /// no other page is loading.
    public func recordScroll(_ position: Double, onPage id: Int) {
        guard id == pageID, id == loads, page != nil else { return }
        history.recordScroll(position)
    }

    /// The page on screen at the scroll it was last reported at, for a web view created after the page was shown,
    /// as when the split view collapses or expands; `nil` when there is none.
    public func resumedPage() -> ArticlePage? {
        guard let article = shown, let current = history.current else { return nil }
        return page(of: article, at: current)
    }

    /// Taps are written one after another, in the order they came, so the model always ends where the file does.
    public func toggleBookmark() async {
        // The tap belongs to the article on screen now, not to whatever is shown when its turn comes.
        guard let article = shown else { return }
        let previous = bookmarkTask
        let task = Task {
            await previous?.value
            await writeBookmarkToggle(of: article)
        }
        bookmarkTask = task
        await task.value
    }

    /// The view has shown the bookmark failure.
    public func dismissBookmarkFailure() {
        bookmarkFailed = false
    }

    private func writeBookmarkToggle(of article: Article) async {
        do {
            let isOn = try await library.toggleBookmark(id: article.id, title: article.title)
            onBookmarksChanged?()
            // Another page may have been opened while this was written.
            guard article == shown else { return }
            isBookmarked = isOn
            bookmarkFailed = false
        } catch {
            if article == shown { bookmarkFailed = true }
        }
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
        loads += 1
        let load = loads
        let article: Article?
        var bookmarked = false
        do {
            article = try await library.article(target.articleID)
            if let article { bookmarked = try await library.isBookmarked(id: article.id, title: article.title) }
        } catch {
            if load == loads { fail(error is CorruptArticle ? .corrupt : .unreadable) }
            return
        }
        // Another page may have been opened while this one loaded.
        guard load == loads else { return }
        guard let article else {
            fail(.notFound)
            return
        }
        page = page(of: article, at: target)
        pageID = load
        contents = article.contents
        isBookmarked = bookmarked
        bookmarkFailed = false
        shown = article
        failure = nil
    }

    private func page(of article: Article, at target: ArticleHistory.Page) -> ArticlePage {
        ArticleHtmlBuilder(today: now(), timeZone: timeZone)
            .build(title: article.title, body: article.body, anchor: target.anchor, scroll: target.scroll)
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
