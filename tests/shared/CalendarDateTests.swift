import Foundation
import Testing
@testable import HisaabCore

struct CalendarDateTests {
    @Test func roundTripsThroughItsIsoText() throws {
        let date = try CalendarDate(isoString: "2026-10-29")

        #expect(date.year == 2026)
        #expect(date.month == 10)
        #expect(date.day == 29)
        #expect(date.isoString == "2026-10-29")
    }

    @Test(arguments: ["2026-02-30", "2026-13-01", "2026-00-10", "2026-10-00", "29/10/2026", "", "2026-1-5"])
    func rejectsDatesThatDoNotExist(text: String) {
        #expect(throws: CalendarDateError.self) {
            try CalendarDate(isoString: text)
        }
    }

    @Test func acceptsTheLastDayOfALeapFebruary() throws {
        #expect(try CalendarDate(isoString: "2028-02-29").day == 29)
    }

    @Test func rejectsFebruary29InAYearThatIsNotALeapYear() {
        #expect(throws: CalendarDateError.self) {
            try CalendarDate(isoString: "2027-02-29")
        }
    }

    @Test func belongsToTheMonthOfItsYearAndMonth() throws {
        let first = try CalendarDate(isoString: "2026-10-01")
        let last = try CalendarDate(isoString: "2026-10-31")
        let next = try CalendarDate(isoString: "2026-11-01")

        #expect(first.yearMonth == last.yearMonth)
        #expect(first.yearMonth != next.yearMonth)
    }

    @Test func ordersByTheCalendar() throws {
        let earlier = try CalendarDate(isoString: "2026-09-30")
        let later = try CalendarDate(isoString: "2026-10-01")

        #expect(earlier < later)
    }

    @Test(arguments: [(2026, 1, "January 2026"), (2026, 10, "October 2026"), (2027, 12, "December 2027")])
    func aMonthHasAReadableTitle(year: Int, month: Int, title: String) {
        #expect(CalendarDate.YearMonth(year: year, month: month).title == title)
    }

    @Test(arguments: [("2026-10-30", "30 Oct"), ("2026-01-05", "5 Jan"), ("2026-12-31", "31 Dec")])
    func aDayHasAShortTitleForLists(iso: String, title: String) throws {
        #expect(try CalendarDate(isoString: iso).shortTitle == title)
    }

    @Test(arguments: [
        (2026, 10, 1, 2026, 11), (2026, 12, 1, 2027, 1), (2026, 1, -1, 2025, 12), (2026, 3, -14, 2025, 1), (2026, 10, 0, 2026, 10),
    ])
    func aMonthCanBeShiftedForwardAndBackAcrossYears(year: Int, month: Int, by: Int, toYear: Int, toMonth: Int) {
        let shifted = CalendarDate.YearMonth(year: year, month: month).shifted(by: by)

        #expect(shifted == CalendarDate.YearMonth(year: toYear, month: toMonth))
    }

    @Test func aDayRoundTripsThroughAnInstantInTheSameCalendar() throws {
        var india = Calendar(identifier: .gregorian)
        india.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let day = try CalendarDate(isoString: "2026-10-30")

        #expect(CalendarDate(day.instant(calendar: india), calendar: india) == day)
    }

    @Test func isReadFromAnInstantUsingTheGivenCalendar() throws {
        var india = Calendar(identifier: .gregorian)
        india.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let justAfterMidnightInIndia = india.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 0, minute: 30))!

        #expect(CalendarDate(justAfterMidnightInIndia, calendar: india).isoString == "2026-10-30")
        #expect(CalendarDate(justAfterMidnightInIndia, calendar: utc).isoString == "2026-10-29")
    }

    @Test(arguments: [
        (2026, 11, 30, 0),
        (2026, 10, 31, 4),
        (2026, 2, 28, 0),
        (2028, 2, 29, 2),
        (2000, 1, 31, 6),
    ])
    func aMonthKnowsItsLengthAndTheWeekdayItStartsOn(year: Int, month: Int, days: Int, firstWeekday: Int) {
        let yearMonth = CalendarDate.YearMonth(year: year, month: month)

        #expect(yearMonth.dayCount == days)
        #expect(yearMonth.firstWeekday == firstWeekday)
    }
}
