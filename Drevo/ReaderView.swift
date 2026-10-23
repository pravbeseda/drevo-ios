import DrevoKit
import SwiftUI

/// One window: the word list beside the article on a regular width, the list with the article pushed over it on a
/// compact one.
struct ReaderView: View {
    @State private var wordList: WordListModel
    @State private var article: ArticleModel
    @SceneStorage("article.window") private var savedWindow: Data?

    init(library: Library, settings: SettingsModel) {
        let wordList = WordListModel(library: library, settings: settings)
        let article = ArticleModel(library: library, baseURL: Bundle.main.resourceURL!)
        article.onBookmarksChanged = { Task { await wordList.bookmarksChanged() } }
        _wordList = State(initialValue: wordList)
        _article = State(initialValue: article)
    }

    var body: some View {
        NavigationSplitView {
            WordListView(model: wordList, selection: selection)
        } detail: {
            ArticleView(model: article)
        }
        // The list stays beside the article whenever the width allows, a portrait iPad included, instead of
        // sliding over it.
        .navigationSplitViewStyle(.balanced)
        .task { await article.start(restoring: savedWindow) }
        .onChange(of: article.history) { savedWindow = article.savedWindow() }
        .onChange(of: article.selection) { savedWindow = article.savedWindow() }
    }

    private var selection: Binding<Int?> {
        Binding(get: { article.selection }, set: { id in Task { await article.select(id) } })
    }
}
