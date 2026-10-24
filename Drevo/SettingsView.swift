import DrevoKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: SettingsModel
    let bookmarksFile: BookmarksFileModel
    @Environment(\.dismiss) private var dismiss
    @State private var export: BookmarksDocument?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Оформление") {
                    Picker("Тема", selection: $settings.theme) {
                        Text("Как в системе").tag(SettingsModel.Theme.system)
                        Text("Светлая").tag(SettingsModel.Theme.light)
                        Text("Тёмная").tag(SettingsModel.Theme.dark)
                    }
                }
                Section {
                    LabeledContent("Размер шрифта") {
                        Text(settings.fontScale, format: .percent.precision(.fractionLength(0)))
                    }
                    Slider(value: $settings.fontScale, in: SettingsModel.fontScales, step: 0.05) {
                        Text("Размер шрифта")
                    }
                } header: {
                    Text("Статья")
                } footer: {
                    Text("Относительно размера текста в настройках системы.")
                }
                Section {
                    Picker("Переводы Библии", selection: $settings.bibleTranslations) {
                        Text("Русский и церковнославянский").tag(SettingsModel.BibleTranslations.both)
                        Text("Только русский").tag(SettingsModel.BibleTranslations.russian)
                        Text("Только церковнославянский").tag(SettingsModel.BibleTranslations.churchSlavonic)
                    }
                }
                Section("Словник") {
                    Picker("Служебные статьи", selection: $settings.list.serviceArticles) {
                        Text("Всегда").tag(ListSettings.ServiceArticles.always)
                        Text("При поиске").tag(ListSettings.ServiceArticles.whileSearching)
                        Text("Никогда").tag(ListSettings.ServiceArticles.never)
                    }
                    Picker("Поиск", selection: $settings.list.searchMatch) {
                        Text("По началу названия").tag(ListSettings.SearchMatch.prefix)
                        Text("По вхождению").tag(ListSettings.SearchMatch.anywhere)
                    }
                }
                Section {
                    Button("Экспортировать…", systemImage: "square.and.arrow.up") {
                        Task { export = await bookmarksFile.exportedFile().map(BookmarksDocument.init) }
                    }
                    Button("Импортировать…", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Закладки")
                } footer: {
                    Text("Импорт добавляет закладки из файла к имеющимся. Файл подходит и для «Древа» на Android.")
                }
            }
            .fileExporter(
                isPresented: Binding(get: { export != nil }, set: { if !$0 { export = nil } }), document: export,
                contentType: .database, defaultFilename: bookmarksFile.exportFileName
            ) { bookmarksFile.exportSaved($0) }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { result in
                Task { await bookmarksFile.importFile(result) }
            }
            .alert(
                bookmarksFile.outcome?.title ?? "",
                isPresented: Binding(
                    get: { bookmarksFile.outcome != nil }, set: { _ in bookmarksFile.dismissOutcome() }),
                presenting: bookmarksFile.outcome
            ) { _ in
            } message: { outcome in
                if let message = outcome.message { Text(message) }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

extension SettingsModel.Theme {
    /// `nil` follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The bookmarks file handed to the system's save dialog.
struct BookmarksDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.database] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension BookmarksFileModel.Outcome {
    var title: String {
        switch self {
        case .imported(0): "Новых закладок нет"
        case .imported: "Закладки добавлены"
        case .notBookmarks: "Это не файл закладок"
        case .importFailed: "Не удалось импортировать закладки"
        case .exportFailed: "Не удалось экспортировать закладки"
        }
    }

    var message: String? {
        switch self {
        case .imported(0): "Все закладки из файла уже есть."
        case .imported(let count): "Добавлено закладок: \(count)."
        case .notBookmarks: "Выберите файл, сохранённый экспортом закладок «Древа»."
        case .importFailed, .exportFailed: nil
        }
    }
}
