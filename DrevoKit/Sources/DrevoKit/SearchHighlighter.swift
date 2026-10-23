import Foundation

/// Finds the search in a word list title to bold it; titles are stored in upper case, so the search is matched that way.
public enum SearchHighlighter {
    public static func matches(of search: String, in title: String) -> [Range<String.Index>] {
        let needle = search.uppercased()
        return needle.isEmpty ? [] : title.ranges(of: needle)
    }

    /// The title with every match strongly emphasised, which `Text` shows in bold.
    public static func highlighted(_ search: String, in title: String) -> AttributedString {
        var highlighted = AttributedString(title)
        for match in matches(of: search, in: title) {
            if let range = Range(match, in: highlighted) {
                highlighted[range].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return highlighted
    }
}
