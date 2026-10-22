/// Applies a javaxdelta text delta (`com.nothome.delta.text`, the format drevo-db stores) to its base text.
///
/// A delta is a `gdt` line followed by commands, numbers in hexadecimal: `y<offset>,<length>` copies from the base,
/// `i<length>` inserts the `<length>` units after its line break, and a line break ends the inserted text. Offsets and
/// lengths count UTF-16 code units, as Java's `CharBuffer` does, so the patch runs over `utf16`: counting characters
/// or Unicode scalars would misplace every edit after a character outside the BMP.
enum TextPatcher {
    struct InvalidDelta: Error, CustomStringConvertible {
        let description: String
    }

    static func patch(_ base: String, with delta: String) throws -> String {
        let source = Array(base.utf16)
        var reader = LineReader(units: Array(delta.utf16))
        guard let header = reader.line(), String(decoding: header, as: UTF16.self) == "gdt" else {
            throw InvalidDelta(description: "no gdt header")
        }
        var output: [UInt16] = []
        while let line = reader.line() {
            switch line.first {
            case Unit.copy:
                guard let comma = line.firstIndex(of: Unit.comma),
                    let offset = hex(line[(line.startIndex + 1)..<comma]),
                    let length = hex(line[(comma + 1)...]),
                    offset <= source.count, length <= source.count - offset
                else { throw InvalidDelta(description: "invalid copy \(String(decoding: line, as: UTF16.self))") }
                output += source[offset..<(offset + length)]
            case Unit.insert:
                guard let length = hex(line.dropFirst()), let text = reader.take(length) else {
                    throw InvalidDelta(description: "invalid insert \(String(decoding: line, as: UTF16.self))")
                }
                output += text
                _ = reader.line()
            default:
                throw InvalidDelta(description: "invalid command \(String(decoding: line, as: UTF16.self))")
            }
        }
        return String(decoding: output, as: UTF16.self)
    }

    private static func hex(_ digits: ArraySlice<UInt16>) -> Int? {
        Int(String(decoding: digits, as: UTF16.self), radix: 16).flatMap { $0 >= 0 ? $0 : nil }
    }
}

/// Reads a delta the way javaxdelta's `BufferedReader` does: lines end at `\n`, `\r` or `\r\n`, and an insert takes
/// raw units, line breaks included.
private struct LineReader {
    let units: [UInt16]
    var position = 0

    /// The next line without its line break, or `nil` at the end of the delta.
    mutating func line() -> ArraySlice<UInt16>? {
        guard position < units.count else { return nil }
        let start = position
        while position < units.count, units[position] != Unit.lf, units[position] != Unit.cr {
            position += 1
        }
        let line = units[start..<position]
        if position < units.count {
            let isCRLF = units[position] == Unit.cr && units.dropFirst(position + 1).first == Unit.lf
            position += isCRLF ? 2 : 1
        }
        return line
    }

    mutating func take(_ count: Int) -> ArraySlice<UInt16>? {
        guard count <= units.count - position else { return nil }
        defer { position += count }
        return units[position..<(position + count)]
    }
}

private enum Unit {
    static let copy = UInt16(UInt8(ascii: "y"))
    static let insert = UInt16(UInt8(ascii: "i"))
    static let comma = UInt16(UInt8(ascii: ","))
    static let lf = UInt16(UInt8(ascii: "\n"))
    static let cr = UInt16(UInt8(ascii: "\r"))
}
