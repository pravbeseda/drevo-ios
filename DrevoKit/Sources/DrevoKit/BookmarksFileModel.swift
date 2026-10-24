import Foundation
import Observation

/// Exports the bookmarks to a file and imports them from one, for the settings screen. An import adds to the
/// bookmarks rather than replacing them, so a wrong file loses nothing.
@MainActor
@Observable
public final class BookmarksFileModel {
    public enum Outcome: Equatable, Sendable {
        case imported(count: Int)
        case notBookmarks
        case importFailed
        case exportFailed
    }

    /// What the last export or import came to, until the view has shown it; a successful export shows nothing.
    public private(set) var outcome: Outcome?
    @ObservationIgnored public var onBookmarksChanged: (@MainActor () -> Void)?

    @ObservationIgnored private let library: Library
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let timeZone: TimeZone

    public init(library: Library, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current) {
        self.library = library
        self.now = now
        self.timeZone = timeZone
    }

    /// drevo-android's name for an export, with today's date.
    public var exportFileName: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "DrevoBookmarks-%04d%02d%02d.db", day.year!, day.month!, day.day!)
    }

    /// The bookmarks file's contents, or `nil` with `exportFailed` as the outcome.
    public func exportedFile() async -> Data? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try await library.exportBookmarks(to: url)
            return try Data(contentsOf: url)
        } catch {
            outcome = .exportFailed
            return nil
        }
    }

    /// What the system's save dialog reports; only a failure other than a cancel becomes an outcome.
    public func exportSaved(_ result: Result<URL, any Error>) {
        if case .failure(let error) = result, !Self.isCancel(error) { outcome = .exportFailed }
    }

    /// Adds the bookmarks of a file the user picked, which may lie outside the app's sandbox.
    public func importFile(_ picked: Result<URL, any Error>) async {
        let url: URL
        do {
            url = try picked.get()
        } catch {
            if !Self.isCancel(error) { outcome = .importFailed }
            return
        }
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let count = try await library.mergeBookmarks(from: url)
            outcome = .imported(count: count)
            if count > 0 { onBookmarksChanged?() }
        } catch is NotBookmarks {
            outcome = .notBookmarks
        } catch {
            outcome = .importFailed
        }
    }

    public func dismissOutcome() {
        outcome = nil
    }

    private static func isCancel(_ error: any Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }
}
