/// What the word list shows: a topic of `tblTopics` (format.md), all articles, or the bookmarks.
public enum Topic: Int, CaseIterable, Codable, Sendable {
    case bookmarks = 0
    case persons = 1
    case organisations, places, terms, church, bible, books, saints, holidays, churchSlavonic, documents
    case all = 99
}

/// The user's word list preferences: drevo-android's `slovnikMode`, `searchType` and `slovnikPortion`.
public struct ListSettings: Equatable, Codable, Sendable {
    /// Service articles are those in topic 13 and up, which topic 99 leaves out.
    public enum ServiceArticles: String, Codable, Sendable {
        case always, whileSearching, never
    }

    public enum SearchMatch: String, Codable, Sendable {
        case prefix, anywhere
    }

    public var serviceArticles: ServiceArticles
    public var searchMatch: SearchMatch
    /// The most rows to show; `nil` shows every match.
    public var limit: Int?

    public init(
        serviceArticles: ServiceArticles = .whileSearching, searchMatch: SearchMatch = .anywhere, limit: Int? = nil
    ) {
        self.serviceArticles = serviceArticles
        self.searchMatch = searchMatch
        self.limit = limit
    }
}

/// Everything one load of the word list depends on.
public struct WordListQuery: Equatable, Sendable {
    public var topic: Topic
    public var search: String
    public var settings: ListSettings

    public init(topic: Topic, search: String, settings: ListSettings) {
        self.topic = topic
        self.search = search
        self.settings = settings
    }
}

/// One row of the word list.
public struct WordEntry: Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let title: String
}

/// Builds the word list SQL. The search is bound as a parameter, where drevo-android splices it into the text.
enum SlovnikQueryBuilder {
    static func build(_ query: WordListQuery) -> (sql: String, search: String?) {
        var sql: String
        if query.topic == .bookmarks {
            sql = "SELECT _id, title FROM tblSlovnik WHERE 1"
        } else {
            sql = "SELECT DISTINCT _id, title FROM tblSlovnik JOIN tblTopics ON _id = article_id WHERE 1"
            let settings = query.settings
            let hidesServiceArticles =
                settings.serviceArticles == .never
                || (settings.serviceArticles == .whileSearching && query.search.isEmpty)
            if query.topic != .all || hidesServiceArticles {
                sql += " AND topic = \(query.topic.rawValue)"
            }
        }
        var pattern: String?
        if !query.search.isEmpty {
            // Titles are stored in upper case (format.md); SQLite's LIKE folds ASCII only.
            let literal = query.search.uppercased()
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
            pattern = (query.settings.searchMatch == .anywhere ? "%" : "") + literal + "%"
            sql += " AND title LIKE ? ESCAPE '\\'"
        }
        // The main page leads the list; format.md leaves that to the client.
        sql += " ORDER BY _id <> 4, title"
        if let limit = query.settings.limit {
            sql += " LIMIT \(limit)"
        }
        return (sql, pattern)
    }
}

/// Loads the word list from the patch database, or from the bookmarks database, whose table has the same shape.
struct WordListReader {
    let patch: SQLiteDatabase
    let bookmarks: SQLiteDatabase

    func load(_ query: WordListQuery) throws -> [WordEntry] {
        let (sql, search) = SlovnikQueryBuilder.build(query)
        let statement = try (query.topic == .bookmarks ? bookmarks : patch).prepare(sql)
        if let search { try statement.bind(search, at: 1) }
        var entries: [WordEntry] = []
        while try statement.step() {
            let title = statement.text(at: 1) ?? ""
            entries.append(WordEntry(id: statement.int(at: 0), title: title.trimmingCharacters(in: .whitespaces)))
        }
        return entries
    }
}
