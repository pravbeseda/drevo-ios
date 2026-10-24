import Foundation
import Observation

/// The user's settings, kept in `UserDefaults` as one JSON value.
@MainActor
@Observable
public final class SettingsModel {
    public enum Theme: String, Codable, CaseIterable, Sendable {
        case system, light, dark
    }

    /// Which translations a Bible passage shows: drevo-android's `bibleTranslate`.
    public enum BibleTranslations: String, Codable, Sendable {
        case both, russian, churchSlavonic
    }

    /// The article text size relative to the system's Dynamic Type size.
    public static let fontScales: ClosedRange<Double> = 0.75...2

    static let key = "settings"

    private struct Stored: Codable {
        var theme = Theme.system
        var fontScale = 1.0
        var list = ListSettings()
        var bibleTranslations = BibleTranslations.both

        init() {}

        /// A key a newer version added is missing from older settings, which keep their other values.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            theme = try container.decode(Theme.self, forKey: .theme)
            fontScale = try container.decode(Double.self, forKey: .fontScale)
            list = try container.decode(ListSettings.self, forKey: .list)
            bibleTranslations =
                try container.decodeIfPresent(BibleTranslations.self, forKey: .bibleTranslations) ?? .both
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var stored: Stored {
        didSet { defaults.set(try? JSONEncoder().encode(stored), forKey: Self.key) }
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        // Unreadable settings, as from a format this version does not know, start over from the defaults.
        stored =
            defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
    }

    public var theme: Theme {
        get { stored.theme }
        set { stored.theme = newValue }
    }

    public var fontScale: Double {
        get { stored.fontScale }
        set { stored.fontScale = min(max(newValue, Self.fontScales.lowerBound), Self.fontScales.upperBound) }
    }

    /// The article page's zoom: `fontScale` on top of the system text size, given as its scale from the default.
    public func textZoom(systemTextScale: Double) -> Double {
        fontScale * systemTextScale
    }

    public var list: ListSettings {
        get { stored.list }
        set { stored.list = newValue }
    }

    public var bibleTranslations: BibleTranslations {
        get { stored.bibleTranslations }
        set { stored.bibleTranslations = newValue }
    }
}
