import Testing

@testable import DrevoKit

/// Deltas are written by hand in javaxdelta's text format: a `gdt` line, then `y<offset>,<length>` copies from the
/// base and `i<length>` inserts the next `<length>` characters, all numbers hexadecimal and in UTF-16 code units.
struct TextPatcherTests {
    @Test func copiesAndInsertsInOrder() throws {
        #expect(try TextPatcher.patch("Слово войны.", with: "gdt\ny0,6\ni4\nмира\nyb,1\n") == "Слово мира.")
    }

    @Test func insertedTextMayHoldLineBreaks() throws {
        let delta = "gdt\ni5\na\nb\r\n\ny0,3\n"
        #expect(try TextPatcher.patch("xyz", with: delta) == "a\nb\r\nxyz")
    }

    @Test func emptyDeltaBodyYieldsAnEmptyText() throws {
        #expect(try TextPatcher.patch("base", with: "gdt\n") == "")
    }

    @Test func lastCommandMayLackItsLineBreak() throws {
        #expect(try TextPatcher.patch("base", with: "gdt\ny0,4") == "base")
    }

    // "𝔇" (U+1D507) is two UTF-16 code units; offsets and lengths count those, not characters.
    @Test func countsUTF16CodeUnitsAcrossSurrogatePairs() throws {
        let base = "a𝔇b"
        #expect(try TextPatcher.patch(base, with: "gdt\ny0,3\n") == "a𝔇")
        #expect(try TextPatcher.patch(base, with: "gdt\ny3,1\ni2\n𝔇\n") == "b𝔇")
    }

    @Test func surrogatePairSplitBetweenTwoCopiesIsJoinedAgain() throws {
        #expect(try TextPatcher.patch("a𝔇", with: "gdt\ny0,2\ny2,1\n") == "a𝔇")
    }

    @Test(arguments: [
        "", "gdx\ny0,1\n", "gdt\n\ny0,1\n", "gdt\nz1\n", "gdt\ny01\n", "gdt\nyq,1\n", "gdt\ny0,5\n", "gdt\ny9,1\n",
        "gdt\ni5\nabc",
    ])
    func rejectsAnInvalidDelta(delta: String) {
        #expect(throws: TextPatcher.InvalidDelta.self) { try TextPatcher.patch("base", with: delta) }
    }
}
