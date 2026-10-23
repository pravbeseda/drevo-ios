import DrevoKit
import SwiftUI

/// The app's version and the drevo-db release it bundles, from the `db.lock` copied into the bundle.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Версия", value: version)
                    LabeledContent("База статей", value: databaseRelease)
                } footer: {
                    Text("Православная энциклопедия «Древо» без подключения к сети.")
                }
                Link("drevo-info.ru", destination: URL(string: "https://drevo-info.ru")!)
            }
            .navigationTitle("О приложении")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var databaseRelease: String {
        let lock = Bundle.main.url(forResource: "db", withExtension: "lock").flatMap { try? String(contentsOf: $0) }
        return lock.flatMap(DatabaseLock.release(in:)) ?? "—"
    }
}
