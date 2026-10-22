import Foundation

/// One entry of an article's table of contents.
struct TocEntry: Equatable {
    let title: String
    let anchor: String
    /// Written `#_anchor|title`: the entry sits under the one before it.
    let isNested: Bool
}

/// An article's text split at `<drevo>` into its table of contents and its HTML body (format.md, "Texts").
struct Article: Equatable {
    let id: Int
    let title: String
    /// In article order; titles repeat within some articles, so it is a list, not a map.
    let contents: [TocEntry]
    let body: String

    init(id: Int, title: String, text: String) {
        self.id = id
        self.title = title
        guard let separator = text.range(of: "<drevo>") else {
            contents = []
            body = text
            return
        }
        body = String(text[separator.upperBound...])
        contents = text[..<separator.lowerBound].split(separator: "#").compactMap { entry in
            // As Java's split, which drew the format: trailing empty fields do not count.
            var fields = entry.trimmed.split(separator: "|", omittingEmptySubsequences: false)
            while fields.last?.isEmpty == true { fields.removeLast() }
            guard fields.count == 2 else { return nil }
            let anchor = fields[0].trimmed
            let entryTitle = fields[1].trimmed
            return TocEntry(
                title: entryTitle == "Начало статьи" ? title : entryTitle,
                anchor: anchor.replacingOccurrences(of: "_", with: ""),
                isNested: anchor.contains("_"))
        }
    }
}

extension StringProtocol {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
