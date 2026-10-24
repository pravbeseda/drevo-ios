import Foundation

/// The databases the reader works on: the bundled `main` and `patch`, and the user's bookmarks. An actor, so the
/// SQLite work runs off the main actor and each connection is used by one task at a time.
public actor Library {
    private let reader: ArticleReader
    private let patch: SQLiteDatabase
    private let bookmarks: BookmarksStore

    public init(main: URL, patch: URL, bookmarks: URL) throws {
        let patchDatabase = try SQLiteDatabase(readOnlyAt: patch)
        reader = ArticleReader(patch: patchDatabase, main: try SQLiteDatabase(readOnlyAt: main))
        self.patch = patchDatabase
        self.bookmarks = try BookmarksStore(at: bookmarks)
    }

    func words(_ query: WordListQuery) throws -> [WordEntry] {
        try WordListReader(patch: patch, bookmarks: bookmarks.database).load(query)
    }

    /// `nil` when the index has no such article; throws `CorruptArticle` when its text cannot be assembled.
    func article(_ id: Int) throws -> Article? {
        guard let rows = try reader.read(id: id) else { return nil }
        let text = try ArticleAssembler.assemble(
            patch: rows.patchBlob, main: rows.mainBlob, patchIsFullText: rows.patchIsFullText)
        return Article(id: id, title: rows.title, text: text)
    }

    func id(forTitle title: String) throws -> Int? {
        try reader.id(forTitle: title)
    }

    func isBookmarked(id: Int, title: String) throws -> Bool {
        try bookmarks.contains(id: id, title: title)
    }

    /// Adds the bookmark when it is absent and removes it when present, in one step of the actor, so two quick taps
    /// add and then remove; returns whether it is now set.
    func toggleBookmark(id: Int, title: String) throws -> Bool {
        let isOn = try !bookmarks.contains(id: id, title: title)
        try setBookmark(isOn, id: id, title: title)
        return isOn
    }

    func exportBookmarks(to url: URL) throws {
        try bookmarks.export(to: url)
    }

    /// Returns how many bookmarks were added.
    func mergeBookmarks(from url: URL) throws -> Int {
        try bookmarks.merge(from: url)
    }

    func setBookmark(_ isOn: Bool, id: Int, title: String) throws {
        if isOn {
            try bookmarks.add(id: id, title: title)
        } else {
            try bookmarks.remove(id: id, title: title)
        }
    }
}
