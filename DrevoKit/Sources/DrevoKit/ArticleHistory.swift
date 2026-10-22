/// The pages the article view went through, for its back and forward buttons. Independent of the web view's own
/// history, which a reload or a new web view would lose; `Codable` so a scene can restore it.
public struct ArticleHistory: Equatable, Codable, Sendable {
    public struct Page: Equatable, Codable, Sendable {
        public let articleID: Int
        public let anchor: String?
        /// How far down the page was read, as a fraction of the document height.
        public var scroll: Double
    }

    public private(set) var current: Page?
    private var backward: [Page] = []
    private var forward: [Page] = []

    public init() {}

    public var canGoBack: Bool { !backward.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// Opens a page as a new step: the forward pages are dropped, and reopening the current page adds nothing.
    public mutating func open(_ articleID: Int, anchor: String? = nil) {
        forward.removeAll()
        guard current?.articleID != articleID || current?.anchor != anchor else { return }
        if let current { backward.append(current) }
        current = Page(articleID: articleID, anchor: anchor, scroll: 0)
    }

    public mutating func recordScroll(_ scroll: Double) {
        current?.scroll = scroll
    }

    /// The page to show, at the scroll it was left at; `nil` when there is none.
    public mutating func goBack() -> Page? {
        guard let current, let previous = backward.popLast() else { return nil }
        forward.append(current)
        self.current = previous
        return previous
    }

    public mutating func goForward() -> Page? {
        guard let current, let next = forward.popLast() else { return nil }
        backward.append(current)
        self.current = next
        return next
    }
}
