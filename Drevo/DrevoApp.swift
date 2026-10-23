import DrevoKit
import SwiftUI

@main
struct DrevoApp: App {
    @State private var settings = SettingsModel(defaults: .standard)
    private let library = Result { try Library.bundled() }

    var body: some Scene {
        WindowGroup {
            switch library {
            case .success(let library):
                ReaderView(library: library, settings: settings)
            case .failure:
                ContentUnavailableView(
                    "Не удалось открыть энциклопедию", systemImage: "exclamationmark.triangle",
                    description: Text("Переустановите приложение."))
            }
        }
    }
}

extension Library {
    /// The databases in the app bundle, and the bookmarks in Application Support under drevo-android's file name.
    static func bundled() throws -> Library {
        let resources = Bundle.main.resourceURL!
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try Library(
            main: resources.appending(path: "main.sqlite"), patch: resources.appending(path: "patch.sqlite"),
            bookmarks: support.appending(path: "bookmarks2.db"))
    }
}
