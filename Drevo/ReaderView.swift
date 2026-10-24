import DrevoKit
import SwiftUI

/// One window: the word list beside the article on a regular width, the list with the article pushed over it on a
/// compact one.
struct ReaderView: View {
    let settings: SettingsModel
    @State private var wordList: WordListModel
    @State private var article: ArticleModel
    @State private var bookmarksFile: BookmarksFileModel
    @State private var sheet: ReaderSheet?
    @SceneStorage("article.window") private var savedWindow: Data?
    /// Read here rather than in a column, whose own size class a split view may narrow.
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(library: Library, settings: SettingsModel) {
        self.settings = settings
        let wordList = WordListModel(library: library, settings: settings)
        let article = ArticleModel(library: library, baseURL: Bundle.main.resourceURL!)
        article.onBookmarksChanged = { Task { await wordList.bookmarksChanged() } }
        let bookmarksFile = BookmarksFileModel(library: library)
        bookmarksFile.onBookmarksChanged = {
            Task {
                await wordList.bookmarksChanged()
                await article.bookmarksChanged()
            }
        }
        _wordList = State(initialValue: wordList)
        _article = State(initialValue: article)
        _bookmarksFile = State(initialValue: bookmarksFile)
    }

    var body: some View {
        NavigationSplitView {
            WordListView(model: wordList, selection: selection)
                .toolbar { menu(where: sizeClass == .compact) }
        } detail: {
            ArticleView(model: article, settings: settings)
                .toolbar { menu(where: sizeClass != .compact) }
        }
        // The list stays beside the article whenever the width allows, a portrait iPad included, instead of
        // sliding over it.
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings: SettingsView(settings: settings, bookmarksFile: bookmarksFile)
            case .about: AboutView()
            }
        }
        .task { await article.start(restoring: savedWindow) }
        .onChange(of: article.history) { savedWindow = article.savedWindow() }
        .onChange(of: article.selection) { savedWindow = article.savedWindow() }
    }

    /// The "⋯" menu sits over the list on a compact width and over the article on a regular one (decision 8).
    @ToolbarContentBuilder private func menu(where shown: Bool) -> some ToolbarContent {
        if shown {
            ToolbarItem(placement: .primaryAction) { ReaderMenu(article: article, sheet: $sheet) }
        }
    }

    private var selection: Binding<Int?> {
        Binding(get: { article.selection }, set: { id in Task { await article.select(id) } })
    }
}

enum ReaderSheet: Identifiable {
    case settings, about

    var id: Self { self }
}

/// The special pages, settings and the about screen.
struct ReaderMenu: View {
    let article: ArticleModel
    @Binding var sheet: ReaderSheet?

    var body: some View {
        Menu("Меню", systemImage: "ellipsis") {
            Button("Главная страница", systemImage: "house") { Task { await article.open(.mainPage) } }
            Button("Календарь", systemImage: "calendar") { Task { await article.open(.calendar) } }
            Button("Сегодня", systemImage: "sun.max") { Task { await article.openToday() } }
            Button("Завтра", systemImage: "sunrise") { Task { await article.openTomorrow() } }
            Button("Хронология", systemImage: "clock.arrow.circlepath") { Task { await article.open(.chronology) } }
            Divider()
            Button("Об энциклопедии", systemImage: "info.circle") { Task { await article.open(.aboutSite) } }
            Button("О приложении", systemImage: "iphone") { sheet = .about }
            Button("Настройки", systemImage: "gearshape") { sheet = .settings }
        }
    }
}
