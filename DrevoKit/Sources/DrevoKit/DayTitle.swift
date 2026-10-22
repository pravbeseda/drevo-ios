import Foundation

/// The title of a calendar day's article, `<day> <month in the genitive>`, in the Julian calendar (format.md,
/// "Special articles"): 13 days back for today, 12 for tomorrow, which holds from 1900 to 2099.
public enum DayTitle {
    public static func today(at now: Date, in calendar: Calendar) -> String {
        title(of: now, shiftedBy: -13, in: calendar)
    }

    public static func tomorrow(at now: Date, in calendar: Calendar) -> String {
        title(of: now, shiftedBy: -12, in: calendar)
    }

    private static func title(of date: Date, shiftedBy days: Int, in calendar: Calendar) -> String {
        let shifted = calendar.date(byAdding: .day, value: days, to: date)!
        let components = calendar.dateComponents([.day, .month], from: shifted)
        return "\(components.day!) \(monthsInGenitive[components.month! - 1])"
    }

    private static let monthsInGenitive = [
        "ЯНВАРЯ", "ФЕВРАЛЯ", "МАРТА", "АПРЕЛЯ", "МАЯ", "ИЮНЯ", "ИЮЛЯ", "АВГУСТА", "СЕНТЯБРЯ", "ОКТЯБРЯ", "НОЯБРЯ",
        "ДЕКАБРЯ",
    ]
}
