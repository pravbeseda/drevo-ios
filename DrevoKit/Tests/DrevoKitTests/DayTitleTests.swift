import Foundation
import Testing

@testable import DrevoKit

struct DayTitleTests {
    private let moscow = TimeZone(identifier: "Europe/Moscow")!
    private var calendar: Calendar { .gregorian(in: moscow) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func todayIsTheOldStyleDateThirteenDaysBack() {
        #expect(DayTitle.today(at: date(2026, 9, 19), in: moscow) == "6 СЕНТЯБРЯ")
    }

    @Test func tomorrowIsTwelveDaysBack() {
        #expect(DayTitle.tomorrow(at: date(2026, 9, 19), in: moscow) == "7 СЕНТЯБРЯ")
    }

    @Test func theShiftCrossesTheYearBoundary() {
        #expect(DayTitle.today(at: date(2027, 1, 9), in: moscow) == "27 ДЕКАБРЯ")
    }

    @Test func theDayIsTheOneInTheGivenTimeZone() {
        // 01:30 on 20 September in Moscow is still the 19th in UTC.
        let night = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 1, minute: 30))!
        let utc = TimeZone(identifier: "UTC")!

        #expect(DayTitle.today(at: night, in: moscow) == "7 СЕНТЯБРЯ")
        #expect(DayTitle.today(at: night, in: utc) == "6 СЕНТЯБРЯ")
    }
}
