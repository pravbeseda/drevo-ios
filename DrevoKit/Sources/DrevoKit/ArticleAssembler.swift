import Foundation

/// The stored blobs of an article cannot be turned into its text.
public enum CorruptArticle: Error, Equatable {
    case noBaseText
    case cannotInflate(byteCount: Int)
    case invalidDelta(String)
}

/// Builds an article's text from its zlib blobs in the patch and main databases (format.md, "Texts").
enum ArticleAssembler {
    static func assemble(patch: Data?, main: Data?, patchIsFullText: Bool) throws -> String {
        if let patch, patchIsFullText {
            return try text(patch)
        }
        guard let main else { throw CorruptArticle.noBaseText }
        let base = try text(main)
        guard let patch else { return base }
        let delta = try text(patch)
        do {
            return try TextPatcher.patch(base, with: delta)
        } catch {
            throw CorruptArticle.invalidDelta(String(describing: error))
        }
    }

    // Byte for byte, as drevo-db inflates the base text it computes deltas against.
    private static func text(_ blob: Data) throws -> String {
        guard let bytes = Zlib.inflate(blob) else { throw CorruptArticle.cannotInflate(byteCount: blob.count) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// zlib streams (RFC 1950) over `Compression`, whose `.zlib` algorithm is raw deflate (RFC 1951).
enum Zlib {
    /// The inflated bytes, or `nil` when the header, the deflate data or the Adler-32 trailer is wrong.
    static func inflate(_ stream: Data) -> Data? {
        let bytes = [UInt8](stream)
        guard bytes.count >= 6 else { return nil }
        let (cmf, flg) = (bytes[0], bytes[1])
        // Deflate method, a valid header check, and no preset dictionary.
        guard cmf & 0x0F == 8, (UInt16(cmf) << 8 | UInt16(flg)) % 31 == 0, flg & 0x20 == 0 else { return nil }
        let deflated = Data(bytes[2..<(bytes.count - 4)])
        guard let inflated = try? (deflated as NSData).decompressed(using: .zlib) as Data else { return nil }
        let checksum = bytes.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return adler32(inflated) == checksum ? inflated : nil
    }

    static func adler32(_ data: Data) -> UInt32 {
        var (a, b): (UInt32, UInt32) = (1, 0)
        for byte in data {
            a = (a + UInt32(byte)) % 65521
            b = (b + a) % 65521
        }
        return b << 16 | a
    }
}
