import Foundation
import Testing

@testable import DrevoKit

struct DayTitleTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func todayIsTheOldStyleDateThirteenDaysBack() {
        #expect(DayTitle.today(at: date(2026, 9, 19), in: calendar) == "6 СЕНТЯБРЯ")
    }

    @Test func tomorrowIsTwelveDaysBack() {
        #expect(DayTitle.tomorrow(at: date(2026, 9, 19), in: calendar) == "7 СЕНТЯБРЯ")
    }

    @Test func theShiftCrossesTheYearBoundary() {
        #expect(DayTitle.today(at: date(2027, 1, 9), in: calendar) == "27 ДЕКАБРЯ")
    }

    @Test func theDayIsTheOneInTheCalendarsTimeZone() {
        // 01:30 on 20 September in Moscow is still the 19th in UTC.
        let night = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 1, minute: 30))!
        var utc = calendar
        utc.timeZone = TimeZone(identifier: "UTC")!

        #expect(DayTitle.today(at: night, in: calendar) == "7 СЕНТЯБРЯ")
        #expect(DayTitle.today(at: night, in: utc) == "6 СЕНТЯБРЯ")
    }
}
