import DrevoKit
import SwiftUI

/// The article's table of contents; picking an entry closes the sheet and jumps to it.
struct ContentsSheet: View {
    let contents: [TocEntry]
    let onPick: (TocEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // Titles repeat within an article, so rows are told apart by position.
            List(Array(contents.enumerated()), id: \.offset) { _, entry in
                Button(entry.title) {
                    onPick(entry)
                    dismiss()
                }
                .padding(.leading, entry.isNested ? 20 : 0)
            }
            .navigationTitle("Содержание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
