import DrevoKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsModel
    @Environment(\.dismiss) private var dismiss

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
                    Picker("Ограничение результатов", selection: $settings.list.limit) {
                        Text("Не ограничивать").tag(Int?.none)
                        ForEach([100, 500, 1000], id: \.self) { limit in
                            Text("\(limit) статей").tag(Int?.some(limit))
                        }
                    }
                }
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
