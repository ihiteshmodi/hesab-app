import Testing
@testable import HisaabCore

/// Every clock, real or fake, must honour the same contract so tests can trust the fake.
struct DayClockContractTests {
    static let clocks: [any DayClock] = [
        SystemDayClock(),
        FixedDayClock(date: day("2026-10-30")),
    ]

    @Test(arguments: clocks.indices)
    func todayIsAValidCalendarDayThatSurvivesItsOwnTextForm(index: Int) throws {
        let today = Self.clocks[index].today()

        #expect(try CalendarDate(isoString: today.isoString) == today)
    }

    @Test func aFixedClockKeepsReturningTheDayItWasGiven() {
        let clock = FixedDayClock(date: day("2026-10-30"))

        #expect(clock.today() == day("2026-10-30"))
        #expect(clock.today() == clock.today())
    }
}
