/// Finds the search in a word list title to bold it; titles are stored in upper case, so the search is matched that way.
public enum SearchHighlighter {
    public static func matches(of search: String, in title: String) -> [Range<String.Index>] {
        let needle = search.uppercased()
        return needle.isEmpty ? [] : title.ranges(of: needle)
    }
}
