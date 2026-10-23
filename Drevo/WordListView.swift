import DrevoKit
import SwiftUI

/// The word list; its title is the menu that picks the topic.
struct WordListView: View {
    @Bindable var model: WordListModel
    @Binding var selection: Int?

    var body: some View {
        List(model.entries, selection: $selection) { entry in
            Text(SearchHighlighter.highlighted(model.search, in: entry.title))
        }
        // Replaces the inset-grouped list's tall gap under a compact navigation bar.
        .contentMargins(.top, 8, for: .scrollContent)
        .overlay {
            if model.failed {
                ContentUnavailableView("Не удалось загрузить словник", systemImage: "exclamationmark.triangle")
            } else if model.entries.isEmpty && !model.search.isEmpty {
                ContentUnavailableView.search(text: model.search)
            } else if model.entries.isEmpty && model.topic == .bookmarks {
                ContentUnavailableView(
                    "Закладок нет", systemImage: "bookmark",
                    description: Text("Добавьте закладку кнопкой над статьёй."))
            }
        }
        .navigationTitle(model.topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            Picker("Словник", selection: $model.topic) {
                ForEach(Topic.menuOrder, id: \.self) { topic in
                    Label(topic.title, systemImage: topic.symbol)
                }
            }
        }
        // Pinned on every width: a placement that followed the width would not change with it, since `searchable`
        // keeps the one it started with, and the default one scrolls away with the sidebar's list.
        .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск")
        .task(id: model.query) { await model.load() }
    }
}

extension Topic {
    static let menuOrder: [Topic] = [
        .all, .persons, .organisations, .places, .terms, .church, .bible, .books, .saints, .holidays,
        .churchSlavonic, .documents, .bookmarks,
    ]

    var title: LocalizedStringResource {
        switch self {
        case .all: "Все статьи"
        case .persons: "Персоналии"
        case .organisations: "Организации"
        case .places: "География"
        case .terms: "Термины, понятия"
        case .church: "Монастыри, храмы, некрополи"
        case .bible: "Библейский словник"
        case .books: "Библиографический"
        case .saints: "Святыни"
        case .holidays: "Памятные события, праздники"
        case .churchSlavonic: "Церковнославянский"
        case .documents: "Документы"
        case .bookmarks: "Закладки"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tree"
        case .persons: "person"
        case .organisations: "person.3"
        case .places: "mappin.and.ellipse"
        case .terms: "character.book.closed"
        case .church: "building.columns"
        case .bible: "book.closed"
        case .books: "books.vertical"
        case .saints: "cross"
        case .holidays: "calendar"
        case .churchSlavonic: "textformat"
        case .documents: "doc.text"
        case .bookmarks: "bookmark"
        }
    }
}
