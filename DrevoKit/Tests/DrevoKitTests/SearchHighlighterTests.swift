import Testing

@testable import DrevoKit

struct SearchHighlighterTests {
    @Test func anEmptySearchMatchesNothing() {
        #expect(SearchHighlighter.matches(of: "", in: "СЕРГИЙ").isEmpty)
    }

    @Test func theSearchIsMatchedInUpperCase() {
        let title = "СЕРГИЙ"
        #expect(SearchHighlighter.matches(of: "сер", in: title).map { String(title[$0]) } == ["СЕР"])
    }

    @Test func everyOccurrenceIsMatched() {
        let title = "АННАН"
        let matches = SearchHighlighter.matches(of: "ан", in: title)
        #expect(matches.map { title.distance(from: title.startIndex, to: $0.lowerBound) } == [0, 3])
    }

    @Test func aTitleWithoutTheSearchHasNoMatch() {
        #expect(SearchHighlighter.matches(of: "сер", in: "АВРААМ").isEmpty)
    }
}
