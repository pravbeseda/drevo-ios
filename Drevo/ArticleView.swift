import DrevoKit
import SwiftUI

/// The article column: the page, its contents, history and bookmark.
struct ArticleView: View {
    let model: ArticleModel
    let settings: SettingsModel
    /// The system's body text size, which `settings` scales the page from.
    @ScaledMetric(relativeTo: .body) private var bodySize = 17.0
    @State private var showsContents = false
    @State private var jump: AnchorJump?

    var body: some View {
        content
            .navigationTitle(model.page?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Содержание", systemImage: "list.bullet") { showsContents = true }
                        .disabled(model.contents.isEmpty)
                    Button(
                        model.isBookmarked ? "Убрать закладку" : "Добавить закладку",
                        systemImage: model.isBookmarked ? "bookmark.fill" : "bookmark"
                    ) {
                        Task { await model.toggleBookmark() }
                    }
                    .disabled(model.page == nil)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Назад", systemImage: "chevron.backward") { Task { await model.goBack() } }
                        .disabled(!model.history.canGoBack)
                    Spacer()
                    Button("Вперёд", systemImage: "chevron.forward") { Task { await model.goForward() } }
                        .disabled(!model.history.canGoForward)
                }
            }
            .sheet(isPresented: $showsContents) {
                ContentsSheet(contents: model.contents) { entry in jump = AnchorJump(anchor: entry.anchor) }
            }
            .alert(
                "Не удалось сохранить закладку",
                isPresented: Binding(get: { model.bookmarkFailed }, set: { _ in model.dismissBookmarkFailure() })
            ) {}
    }

    @ViewBuilder private var content: some View {
        if let failure = model.failure {
            ContentUnavailableView(failure.title, systemImage: "doc.questionmark")
        } else if model.page != nil {
            ArticleWebView(
                model: model, pageID: model.pageID, jump: jump, zoom: settings.textZoom(bodySize: bodySize)
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// A request to move the page to an anchor; each one is new, so picking the same entry twice jumps twice.
struct AnchorJump: Equatable {
    let anchor: String
    let id = UUID()
}

extension ArticleModel.Failure {
    var title: LocalizedStringResource {
        switch self {
        case .notFound: "Статья не найдена"
        case .corrupt: "Статья повреждена"
        case .unreadable: "Не удалось прочитать статью"
        case .noArticleForDay: "Для этого дня статьи нет"
        }
    }
}
