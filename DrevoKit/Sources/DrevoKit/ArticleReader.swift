import Foundation

/// An article's title and the blobs `ArticleAssembler` builds its text from.
struct ArticleRows: Equatable {
    let title: String
    let patchBlob: Data?
    let mainBlob: Data?
    let patchIsFullText: Bool
}

/// Reads an article's rows from the patch and main databases; titles come from the patch alone.
struct ArticleReader {
    let patch: SQLiteDatabase
    let main: SQLiteDatabase

    /// `nil` when the index has no article with this id.
    func read(id: Int) throws -> ArticleRows? {
        let title = try patch.prepare("SELECT title FROM tblSlovnik WHERE _id = ?")
        try title.bind(id, at: 1)
        guard try title.step(), let titleText = title.text(at: 0) else { return nil }

        let patchText = try patch.prepare("SELECT ziptext, isfulltext FROM tblTexts WHERE _id = ?")
        try patchText.bind(id, at: 1)
        let hasPatchRow = try patchText.step()
        let patchBlob = hasPatchRow ? patchText.blob(at: 0) : nil
        let patchIsFullText = hasPatchRow && patchText.int(at: 1) == 1

        var mainBlob: Data?
        if !(patchBlob != nil && patchIsFullText) {
            let mainText = try main.prepare("SELECT ziptext FROM tblTexts WHERE _id = ?")
            try mainText.bind(id, at: 1)
            mainBlob = try mainText.step() ? mainText.blob(at: 0) : nil
        }
        return ArticleRows(
            title: titleText.trimmingCharacters(in: .whitespaces), patchBlob: patchBlob, mainBlob: mainBlob,
            patchIsFullText: patchIsFullText)
    }
}
