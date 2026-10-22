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
    }

    @Test func changesSurviveANewModel() {
        let settings = SettingsModel(defaults: defaults)
        settings.theme = .dark
        settings.fontScale = 1.25
        settings.list.searchMatch = .prefix
        settings.list.limit = 500

        let reloaded = SettingsModel(defaults: defaults)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.fontScale == 1.25)
        #expect(reloaded.list == ListSettings(searchMatch: .prefix, limit: 500))
    }

    @Test func fontScaleStaysInItsRange() {
        let settings = SettingsModel(defaults: defaults)
        settings.fontScale = 10
        #expect(settings.fontScale == SettingsModel.fontScales.upperBound)
        settings.fontScale = 0
        #expect(settings.fontScale == SettingsModel.fontScales.lowerBound)
    }

    @Test func unreadableStoredSettingsFallBackToTheDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsModel.key)
        #expect(SettingsModel(defaults: defaults).theme == .system)
    }
}
