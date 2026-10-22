import Foundation

/// Where a link in an article leads. Bodies link articles by bare id (`href="16473"`, `href="16473#t2"`), which
/// resolve against the bundle directory the page is loaded from.
public enum ArticleLink: Equatable, Sendable {
    case article(id: Int, anchor: String?)
    /// The loaded page itself, or an anchor on it: the web view handles it.
    case samePage
    /// Another scheme, for the system to open.
    case external(URL)
    /// Any other file path, which the bundle does not hold.
    case ignored

    public init(url: URL, base: URL) {
        guard url.isFileURL else {
            self = .external(url)
            return
        }
        let basePath = base.standardizedFileURL.path
        if url.standardizedFileURL.path == basePath {
            self = .samePage
        } else if url.deletingLastPathComponent().standardizedFileURL.path == basePath,
            url.lastPathComponent.allSatisfy(\.isASCIIDigit), let id = Int(url.lastPathComponent)
        {
            self = .article(id: id, anchor: url.fragment)
        } else {
            self = .ignored
        }
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
