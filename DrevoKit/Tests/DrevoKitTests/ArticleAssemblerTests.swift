import Foundation
import Testing

@testable import DrevoKit

struct ArticleAssemblerTests {
    private static let oldText = "<p>Преподобный Сергий Радонежский</p>\n<p>Память 25 сентября</p>"
    private static let newText = "<p>Преподобный Сергий Радонежский</p>\n<p>Память 8 октября</p>"
    private static let notZlib = Data([1, 2, 3, 4, 5])

    /// A zlib stream (RFC 1950), as drevo-db's `DeflaterOutputStream` writes the blobs.
    private static func zlib(_ text: String) -> Data {
        let raw = Data(text.utf8)
        let deflated = try! (raw as NSData).compressed(using: .zlib) as Data
        let checksum = Zlib.adler32(raw)
        return Data([0x78, 0x9C]) + deflated + withUnsafeBytes(of: checksum.bigEndian) { Data($0) }
    }

    /// Copies everything up to "25 сентября" and inserts the new date.
    private static let delta = zlib("gdt\ny0,30\ni9\n8 октября\ny3b,4\n")

    @Test func fullTextPatchIsTheArticle() throws {
        #expect(
            try ArticleAssembler.assemble(patch: Self.zlib(Self.newText), main: nil, patchIsFullText: true)
                == Self.newText)
    }

    @Test func fullTextPatchWinsOverTheBase() throws {
        let text = try ArticleAssembler.assemble(
            patch: Self.zlib(Self.newText), main: Self.zlib(Self.oldText), patchIsFullText: true)
        #expect(text == Self.newText)
    }

    @Test func withoutPatchTheBaseIsTheArticle() throws {
        #expect(
            try ArticleAssembler.assemble(patch: nil, main: Self.zlib(Self.oldText), patchIsFullText: false)
                == Self.oldText)
    }

    @Test func deltaIsAppliedToTheBase() throws {
        let text = try ArticleAssembler.assemble(
            patch: Self.delta, main: Self.zlib(Self.oldText), patchIsFullText: false)
        #expect(text == Self.newText)
    }

    @Test func textIsReturnedByteForByte() throws {
        let text = "первая строка\r\nвторая строка"
        #expect(try ArticleAssembler.assemble(patch: nil, main: Self.zlib(text), patchIsFullText: false) == text)
    }

    @Test func adler32MatchesTheKnownValue() {
        #expect(Zlib.adler32(Data("Wikipedia".utf8)) == 0x11E6_0398)
    }

    struct Case: CustomTestStringConvertible, Sendable {
        let testDescription: String
        let patch: Data?
        let main: Data?
        let patchIsFullText: Bool
    }

    static let corruptCases: [Case] = {
        let whole = zlib(oldText)
        var badChecksum = whole
        badChecksum[badChecksum.count - 1] ^= 0xFF
        var badHeader = whole
        badHeader[0] = 0x79
        return [
            Case(testDescription: "delta without base", patch: delta, main: nil, patchIsFullText: false),
            Case(testDescription: "neither patch nor base", patch: nil, main: nil, patchIsFullText: false),
            Case(testDescription: "corrupt full-text patch", patch: notZlib, main: nil, patchIsFullText: true),
            Case(
                testDescription: "corrupt full-text patch over a stale base", patch: notZlib, main: whole,
                patchIsFullText: true),
            Case(testDescription: "corrupt base", patch: nil, main: notZlib, patchIsFullText: false),
            Case(testDescription: "delta over a corrupt base", patch: delta, main: notZlib, patchIsFullText: false),
            Case(testDescription: "corrupt delta blob", patch: notZlib, main: whole, patchIsFullText: false),
            Case(
                testDescription: "truncated blob", patch: nil, main: whole.prefix(whole.count / 2),
                patchIsFullText: false),
            Case(testDescription: "wrong checksum", patch: nil, main: badChecksum, patchIsFullText: false),
            Case(testDescription: "not a zlib header", patch: nil, main: badHeader, patchIsFullText: false),
            Case(
                testDescription: "delta that is not a delta", patch: zlib("not a delta"), main: whole,
                patchIsFullText: false),
        ]
    }()

    @Test(arguments: corruptCases)
    func corruptArticleIsReported(_ article: Case) {
        #expect(throws: CorruptArticle.self) {
            try ArticleAssembler.assemble(
                patch: article.patch, main: article.main, patchIsFullText: article.patchIsFullText)
        }
    }
}
