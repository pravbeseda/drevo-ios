import Foundation
import Testing

@testable import DrevoKit

/// Reads and assembles every article of drevo-db's reference build and compares it with the expected text.
struct FormatFixturesTests {
    @Test(arguments: Fixtures.articleIDs)
    func articleAssemblesToItsExpectedText(id: Int) throws {
        let rows = try #require(try ArticleReader(patch: Fixtures.patch(), main: Fixtures.main()).read(id: id))
        let text = try ArticleAssembler.assemble(
            patch: rows.patchBlob, main: rows.mainBlob, patchIsFullText: rows.patchIsFullText)
        #expect(Array(text.utf8) == Array(try Fixtures.expectedText(id).utf8))
    }

    @Test func everyIndexedArticleHasAnExpectedTextAndNoOtherDoes() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: Fixtures.url("expected").path)
        #expect(Set(files) == Set(Fixtures.articleIDs.map { "\($0).txt" }))
        #expect(!Fixtures.articleIDs.isEmpty)
    }
}
