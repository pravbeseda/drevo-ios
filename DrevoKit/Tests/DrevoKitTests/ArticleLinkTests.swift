import Foundation
import Testing

@testable import DrevoKit

/// Links as they appear in article bodies, resolved against the bundle directory the page is loaded from.
struct ArticleLinkTests {
    private let base = URL(fileURLWithPath: "/private/var/Drevo.app/", isDirectory: true)

    private func link(_ href: String) -> ArticleLink {
        ArticleLink(url: URL(string: href, relativeTo: base)!.absoluteURL, base: base)
    }

    @Test func aNumberIsAnArticle() {
        #expect(link("16473") == .article(id: 16473, anchor: nil))
    }

    @Test func aNumberWithAFragmentIsAnArticleAtThatAnchor() {
        #expect(link("16473#t2") == .article(id: 16473, anchor: "t2"))
    }

    @Test func aFragmentAloneStaysOnThePage() {
        #expect(link("#1") == .samePage)
    }

    @Test func thePageItselfStaysOnThePage() {
        #expect(ArticleLink(url: base, base: base) == .samePage)
    }

    @Test(arguments: ["http://drevo-info.ru/images/002/005319.jpg", "https://drevo-info.ru", "mailto:a@b.ru"])
    func otherSchemesOpenOutside(href: String) {
        #expect(link(href) == .external(URL(string: href)!))
    }

    @Test(arguments: ["/pictures/1.html", "picture.jpg", "12a"])
    func otherFilesAreIgnored(href: String) {
        #expect(link(href) == .ignored)
    }
}
