import Foundation

/// The title of a calendar day's article, `<day> <month in the genitive>`, in the Julian calendar (format.md,
/// "Special articles"): 13 days back for today, 12 for tomorrow, which holds from 1900 to 2099.
public enum DayTitle {
    /// `timeZone` decides which day `now` falls on.
    public static func today(at now: Date, in timeZone: TimeZone) -> String {
        title(of: now, shiftedBy: -13, in: timeZone)
    }

    public static func tomorrow(at now: Date, in timeZone: TimeZone) -> String {
        title(of: now, shiftedBy: -12, in: timeZone)
    }

    private static func title(of date: Date, shiftedBy days: Int, in timeZone: TimeZone) -> String {
        let calendar = Calendar.gregorian(in: timeZone)
        let shifted = calendar.date(byAdding: .day, value: days, to: date)!
        let components = calendar.dateComponents([.day, .month], from: shifted)
        return "\(components.day!) \(monthsInGenitive[components.month! - 1])"
    }

    private static let monthsInGenitive = [
        "ЯНВАРЯ", "ФЕВРАЛЯ", "МАРТА", "АПРЕЛЯ", "МАЯ", "ИЮНЯ", "ИЮЛЯ", "АВГУСТА", "СЕНТЯБРЯ", "ОКТЯБРЯ", "НОЯБРЯ",
        "ДЕКАБРЯ",
    ]
}

extension Calendar {
    /// The month names and the Julian shift hold for Gregorian dates only, whatever calendar the user's region uses.
    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
