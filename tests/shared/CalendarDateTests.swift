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
}
