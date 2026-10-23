/// Reads `db.lock`, which the app bundles to name the drevo-db release it carries.
public enum DatabaseLock {
    /// The `DB_RELEASE` value, `db-<main>-<patch>`.
    public static func release(in contents: String) -> String? {
        for line in contents.split(whereSeparator: \.isNewline) where line.hasPrefix("DB_RELEASE=") {
            return String(line.dropFirst("DB_RELEASE=".count))
        }
        return nil
    }
}
