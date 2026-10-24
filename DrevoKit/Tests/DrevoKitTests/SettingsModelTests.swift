import Foundation
import Testing

@testable import DrevoKit

@MainActor
struct SettingsModelTests {
    private let defaults = UserDefaults(suiteName: UUID().uuidString)!

    @Test func startsFromTheDefaults() {
        let settings = SettingsModel(defaults: defaults)
        #expect(settings.theme == .system)
        #expect(settings.fontScale == 1)
        #expect(settings.list == ListSettings())
        #expect(settings.bibleTranslations == .both)
    }

    @Test func changesSurviveANewModel() {
        let settings = SettingsModel(defaults: defaults)
        settings.theme = .dark
        settings.fontScale = 1.25
        settings.list.searchMatch = .prefix
        settings.bibleTranslations = .churchSlavonic

        let reloaded = SettingsModel(defaults: defaults)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.fontScale == 1.25)
        #expect(reloaded.list == ListSettings(searchMatch: .prefix))
        #expect(reloaded.bibleTranslations == .churchSlavonic)
    }

    @Test func settingsStoredBeforeTheBibleSettingKeepTheirValues() {
        defaults.set(
            Data(
                #"{"theme":"dark","fontScale":1.5,"list":{"serviceArticles":"never","searchMatch":"prefix","limit":500}}"#
                    .utf8),
            forKey: SettingsModel.key)
        let settings = SettingsModel(defaults: defaults)
        #expect(settings.theme == .dark)
        #expect(settings.list == ListSettings(serviceArticles: .never, searchMatch: .prefix))
        #expect(settings.bibleTranslations == .both)
    }

    @Test func fontScaleStaysInItsRange() {
        let settings = SettingsModel(defaults: defaults)
        settings.fontScale = 10
        #expect(settings.fontScale == SettingsModel.fontScales.upperBound)
        settings.fontScale = 0
        #expect(settings.fontScale == SettingsModel.fontScales.lowerBound)
    }

    @Test func theTextZoomScalesTheSystemTextSize() {
        let settings = SettingsModel(defaults: defaults)
        #expect(settings.textZoom(systemTextScale: 1) == 1)
        #expect(settings.textZoom(systemTextScale: 1.25) == 1.25)
        settings.fontScale = 1.5
        #expect(settings.textZoom(systemTextScale: 1) == 1.5)
        #expect(settings.textZoom(systemTextScale: 1.25) == 1.875)
    }

    @Test func unreadableStoredSettingsFallBackToTheDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsModel.key)
        #expect(SettingsModel(defaults: defaults).theme == .system)
    }
}
