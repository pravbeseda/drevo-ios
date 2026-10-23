import Foundation
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

    @Test func theHighlightedTitleEmphasisesEveryMatch() {
        let title = SearchHighlighter.highlighted("ан", in: "АННАН")
        #expect(String(title.characters) == "АННАН")
        let emphasised = title.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(emphasised.map { String(title[$0.range].characters) } == ["АН", "АН"])
    }

    @Test func withoutASearchTheTitleIsPlain() {
        let title = SearchHighlighter.highlighted("", in: "АННАН")
        #expect(title.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }
}
