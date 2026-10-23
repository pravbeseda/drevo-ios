import Foundation

/// An article ready for the web view: its displayed title and the whole HTML document.
public struct ArticlePage: Equatable, Sendable {
    public let title: String
    public let html: String
    /// The page scrolls to its anchor on load instead of opening at the top or at a restored position.
    public let opensAtAnchor: Bool
}

/// Wraps an article body into the HTML document the web view loads with the bundle's resource directory as its base,
/// where `style.css`, `styleblack.css`, `common.js` and `jquery.min.js` live. The page reports to the app through
/// the `drevo` message handler: `{event: 'load'}` once loaded, `{event: 'scroll', position}` as it scrolls.
public struct ArticleHtmlBuilder {
    public static let messageHandler = "drevo"

    private let today: DateComponents

    /// `today` is the day the calendar page marks, taken in `timeZone`.
    public init(today: Date, timeZone: TimeZone) {
        self.today = Calendar.gregorian(in: timeZone).dateComponents([.month, .day], from: today)
    }

    /// `scroll` is a fraction of the document height to restore; a non-zero one wins over `anchor`.
    public func build(title: String, body: String, anchor: String?, scroll: Double) -> ArticlePage {
        var pageTitle = title
        var text = body
        if title == "КАЛЕНДАРЬ" {
            if let year = text.firstMatch(of: #/<div class="year">(\d+)</div>/#) {
                pageTitle += " " + year.output.1
                text.removeSubrange(year.range)
            }
            let day = String(format: "%02d%02d", today.month!, today.day!)
            text = text.replacingOccurrences(
                of: #"td id="\#(day)" class="day"#, with: #"td id="\#(day)" class="day today"#)
        }

        let opensAtAnchor = scroll == 0 && !(anchor ?? "").isEmpty
        let position =
            if scroll != 0 {
                "window.scrollTo(0, \(scroll) * $(document).height()); "
            } else if let anchor, opensAtAnchor {
                "window.location.hash = '\(Self.jsStringContent(anchor))'; "
            } else {
                ""
            }
        let post = "webkit.messageHandlers.\(Self.messageHandler).postMessage"
        let html =
            #"<!DOCTYPE html><html><head><meta charset="utf-8">"#
            + #"<meta name="viewport" content="width=device-width, initial-scale=1">"#
            + #"<meta name="color-scheme" content="light dark">"#
            + #"<link rel="stylesheet" href="style.css" media="(prefers-color-scheme: light)">"#
            + #"<link rel="stylesheet" href="styleblack.css" media="(prefers-color-scheme: dark)">"#
            + #"</head><body><a name="top"></a><h1>\#(pageTitle)</h1>\#(text)"#
            + "<script>window.onload = function() { \(position)\(post)({event: 'load'}); "
            + "$(window).scroll(function() { \(post)("
            + "{event: 'scroll', position: $(document).scrollTop() / $(document).height()}); }); }</script>"
            + #"<script src="common.js"></script><script src="jquery.min.js"></script></body></html>"#
        return ArticlePage(title: pageTitle, html: html, opensAtAnchor: opensAtAnchor)
    }

    /// The script that moves a loaded page to one of its anchors, as the contents sheet does.
    public static func jumpScript(to anchor: String) -> String {
        "window.location.hash = '\(jsStringContent(anchor))';"
    }

    /// The script that sets the page's text size; CSS zoom reflows the page to the screen's width, where the web
    /// view's own page zoom would push it past the edge.
    public static func zoomScript(_ zoom: Double) -> String {
        "document.documentElement.style.zoom = '\(zoom)';"
    }

    /// An anchor may come from a restored history or an imported bookmark, so it must not end the string or the
    /// script it lands in.
    private static func jsStringContent(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": escaped += "\\\\"
            case "'": escaped += "\\'"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\"", "<", ">", "\u{2028}", "\u{2029}": escaped += String(format: "\\u%04X", scalar.value)
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped
    }
}
