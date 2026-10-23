import Foundation
import Testing

@testable import DrevoKit

struct ArticleHtmlBuilderTests {
    private let builder: ArticleHtmlBuilder = {
        let moscow = TimeZone(identifier: "Europe/Moscow")!
        let october5 = Calendar.gregorian(in: moscow).date(
            from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!
        return ArticleHtmlBuilder(today: october5, timeZone: moscow)
    }()

    private func build(title: String = "ТИТУЛ", body: String = "<p>text</p>", anchor: String? = nil, scroll: Double = 0)
        -> ArticlePage
    {
        builder.build(title: title, body: body, anchor: anchor, scroll: scroll)
    }

    @Test func buildsTheWholeDocument() {
        let page = build()
        #expect(
            page.html == """
                <!DOCTYPE html><html><head><meta charset="utf-8">\
                <meta name="viewport" content="width=device-width, initial-scale=1">\
                <meta name="color-scheme" content="light dark">\
                <link rel="stylesheet" href="style.css" media="(prefers-color-scheme: light)">\
                <link rel="stylesheet" href="styleblack.css" media="(prefers-color-scheme: dark)">\
                </head><body><a name="top"></a><h1>ТИТУЛ</h1><p>text</p>\
                <script>window.onload = function() { \
                webkit.messageHandlers.drevo.postMessage({event: 'load'}); \
                $(window).scroll(function() { webkit.messageHandlers.drevo.postMessage(\
                {event: 'scroll', position: $(document).scrollTop() / $(document).height()}); }); }</script>\
                <script src="common.js"></script><script src="jquery.min.js"></script></body></html>
                """)
        #expect(page.title == "ТИТУЛ")
        #expect(!page.opensAtAnchor)
    }

    @Test func opensAtTheAnchorWhenThereIsNoScrollToRestore() {
        let page = build(anchor: "part2")
        #expect(page.html.contains("window.onload = function() { window.location.hash = 'part2'; webkit"))
        #expect(page.opensAtAnchor)
    }

    @Test func restoredScrollWinsOverTheAnchor() {
        let page = build(anchor: "part2", scroll: 0.5)
        #expect(
            page.html.contains("window.onload = function() { window.scrollTo(0, 0.5 * $(document).height()); webkit"))
        #expect(!page.html.contains("location.hash"))
        #expect(!page.opensAtAnchor)
    }

    @Test func anAnchorCannotCloseItsStringLiteral() {
        let page = build(anchor: "'; document.body.innerHTML='injected'; '")
        #expect(page.html.contains(#"window.location.hash = '\'; document.body.innerHTML=\'injected\'; \''; "#))
    }

    @Test func anAnchorCannotCloseItsScriptElement() {
        let page = build(anchor: "</script><script>alert(1)</script>")
        #expect(!page.html.contains("<script>alert"))
        #expect(
            page.html.contains(
                "window.location.hash = '\\u003C/script\\u003E\\u003Cscript\\u003Ealert(1)\\u003C/script\\u003E'; "))
    }

    @Test func anAnchorCannotBreakItsLine() {
        let page = build(anchor: "a\\b\"c\nd\re\u{2028}f\u{2029}g")
        #expect(page.html.contains("window.location.hash = 'a\\\\b\\u0022c\\nd\\re\\u2028f\\u2029g'; "))
    }

    @Test func aPercentEncodedAnchorIsKeptAsIs() {
        #expect(build(anchor: "%D0%B3%D0%BB.2").html.contains("window.location.hash = '%D0%B3%D0%BB.2'; "))
    }

    @Test func theJumpScriptMovesToTheAnchor() {
        #expect(ArticleHtmlBuilder.jumpScript(to: "t2") == "window.location.hash = 't2';")
    }

    @Test func aJumpAnchorCannotCloseItsStringLiteral() {
        #expect(ArticleHtmlBuilder.jumpScript(to: "a'b") == #"window.location.hash = 'a\'b';"#)
    }

    @Test func calendarMovesItsYearIntoTheTitle() {
        let page = build(title: "КАЛЕНДАРЬ", body: #"<div class="year">2026</div><table></table>"#)
        #expect(page.title == "КАЛЕНДАРЬ 2026")
        #expect(page.html.contains("<h1>КАЛЕНДАРЬ 2026</h1><table></table>"))
    }

    @Test func calendarWithoutAYearKeepsItsTitle() {
        #expect(build(title: "КАЛЕНДАРЬ", body: "<table></table>").title == "КАЛЕНДАРЬ")
    }

    @Test func calendarMarksToday() {
        let page = build(title: "КАЛЕНДАРЬ", body: #"<td id="1004" class="day"><td id="1005" class="day">"#)
        #expect(page.html.contains(#"<td id="1004" class="day"><td id="1005" class="day today">"#))
    }

    // 261 of the 365 days in db-254-258's calendar carry more classes than `day`.
    @Test func calendarMarksTodayWhateverItsOtherClasses() {
        let page = build(title: "КАЛЕНДАРЬ", body: #"<td id="1005" class="day weekend post">"#)
        #expect(page.html.contains(#"<td id="1005" class="day today weekend post">"#))
    }

    @Test func onlyTheCalendarMarksToday() {
        let body = #"<td id="1005" class="day">"#
        #expect(build(body: body).html.contains(body))
    }
}
