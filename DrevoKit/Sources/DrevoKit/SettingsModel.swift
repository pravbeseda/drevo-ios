import Foundation
import Observation

/// The user's settings, kept in `UserDefaults` as one JSON value.
@MainActor
@Observable
public final class SettingsModel {
    public enum Theme: String, Codable, CaseIterable, Sendable {
        case system, light, dark
    }

    /// The article text size relative to the system's Dynamic Type size.
    public static let fontScales: ClosedRange<Double> = 0.75...2

    static let key = "settings"

    private struct Stored: Codable {
        var theme = Theme.system
        var fontScale = 1.0
        var list = ListSettings()
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

    /// The article page's zoom: `fontScale` on top of the system text size, given as the body text style's size in
    /// points, whose default is 17.
    public func textZoom(bodySize: Double) -> Double {
        fontScale * bodySize / 17
    }

    public var list: ListSettings {
        get { stored.list }
        set { stored.list = newValue }
    }
}
