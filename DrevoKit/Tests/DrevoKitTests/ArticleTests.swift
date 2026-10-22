import Testing

@testable import DrevoKit

struct ArticleTests {
    private func article(_ text: String) -> Article {
        Article(id: 102, title: "СЕРГИЙ РАДОНЕЖСКИЙ", text: text)
    }

    @Test func tableOfContentsKeepsOrderAndMarksNestedEntries() throws {
        let article = article(try Fixtures.expectedText(102))

        #expect(
            article.contents == [
                TocEntry(title: "СЕРГИЙ РАДОНЕЖСКИЙ", anchor: "t0", isNested: false),
                TocEntry(title: "Житие", anchor: "t1", isNested: false),
                TocEntry(title: "Детство", anchor: "t2", isNested: true),
                TocEntry(title: "Постриг", anchor: "t3", isNested: true),
                TocEntry(title: "Почитание", anchor: "t4", isNested: false),
            ])
        #expect(article.body.hasPrefix(" <p>Преподобный Сергий Радонежский"))
    }

    @Test func repeatedTitlesKeepTheirOwnAnchors() {
        let article = article(
            "#t0| Начало статьи #t1| В Греции #_t2| Предание #t3| В России #_t4| Предание  <drevo> <p>Текст</p>")

        #expect(
            article.contents == [
                TocEntry(title: "СЕРГИЙ РАДОНЕЖСКИЙ", anchor: "t0", isNested: false),
                TocEntry(title: "В Греции", anchor: "t1", isNested: false),
                TocEntry(title: "Предание", anchor: "t2", isNested: true),
                TocEntry(title: "В России", anchor: "t3", isNested: false),
                TocEntry(title: "Предание", anchor: "t4", isNested: true),
            ])
        #expect(article.body == " <p>Текст</p>")
    }

    // format.md: only a leading underscore marks nesting; one inside an anchor is part of its name.
    @Test func onlyALeadingUnderscoreMarksNesting() {
        let article = article("#section_one|Житие #_part_two|Детство <drevo>текст")

        #expect(
            article.contents == [
                TocEntry(title: "Житие", anchor: "section_one", isNested: false),
                TocEntry(title: "Детство", anchor: "part_two", isNested: true),
            ])
    }

    @Test func malformedEntriesAreSkipped() {
        let article = article("#t0|Житие #broken #t1|a|b #t2|Почитание <drevo>текст")
        #expect(article.contents.map(\.anchor) == ["t0", "t2"])
    }

    @Test func textWithoutTableOfContentsIsShownWhole() {
        let article = article("<p>Статья не найдена</p>")

        #expect(article.contents.isEmpty)
        #expect(article.body == "<p>Статья не найдена</p>")
    }
}
