import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/bills/bills.feature: Activity > Upcoming, the Bills calendar and its filter menu.
struct BillsCalendarTests {
    private func newBill(
        _ name: String, _ rupees: Int, due: String, repeats: BillRepeat = .monthly, ends: String? = nil,
        automatic: Bool = false
    ) -> NewBill {
        NewBill(
            name: name, amount: .rupees(rupees), category: "Home & Utilities",
            dueDate: day(due), repeats: repeats, endsOn: ends.map(day), addAutomatically: automatic
        )
    }

    /// The feature's background bills.
    private func background(today: String = "2026-10-30", rentEnds: String? = nil) throws -> BudgetApp {
        let app = try makeApp(today: today)
        try app.addBill(newBill("Rent", 20_000, due: "2026-11-01", ends: rentEnds))
        try app.addBill(newBill("Insurance premium", 1_500, due: "2026-11-10"))
        try app.addBill(newBill("Society maintenance", 6_000, due: "2026-11-12", repeats: .every3Months))
        try app.addBill(newBill("Internet", 800, due: "2026-11-16", automatic: true))
        try app.addBill(newBill("Property tax", 3_000, due: "2027-04-02", repeats: .yearly))
        return app
    }

    /// Today 2026-11-16: Internet added itself, Rent was added by hand, a scheme pays on the 20th, a salary came in.
    private func midNovember() throws -> BudgetApp {
        let app = try background(today: "2026-11-16")
        _ = try app.runAutomaticBills()
        let rent = try #require(try app.bills().first { $0.bill.name == "Rent" }).bill
        try app.addBillOccurrence(rent.id, try app.billDraft(rent.id))
        try app.addScheme(NewPayoutScheme(
            name: "RBI bond", invested: .rupees(1_00_000), monthlyPayout: .rupees(2_000), payoutDay: 20, maturity: nil
        ))
        try app.addIncome(NewIncome(date: day("2026-11-01"), kind: .salary, amount: .rupees(1_50_000)))
        return app
    }

    private let november = CalendarDate.YearMonth(year: 2026, month: 11)
    private let december = CalendarDate.YearMonth(year: 2026, month: 12)

    // MARK: Activity > Upcoming

    @Test func aBillThatAddsItselfDoesNotWaitInUpcoming() throws {
        let app = try background()
        try app.updatePreferences { $0.upcomingWindowDays = 30 }

        let names = try app.upcoming().items.map(\.bill.name)

        #expect(names == ["Rent", "Insurance premium", "Society maintenance"])
    }

    @Test func anAutomaticAddThatWasUndoneWaitsInUpcoming() throws {
        let app = try background(today: "2026-11-16")
        _ = try app.runAutomaticBills()
        let added = try #require(try app.autoAdded().first)

        try app.undoAutoAdded(added.occurrenceID)

        let internet = try #require(try app.upcoming().items.first { $0.bill.name == "Internet" })
        #expect(internet.label == "Due today")
    }

    // MARK: the calendar

    @Test func theCalendarPutsEveryBillOnItsDay() throws {
        let app = try background()

        let items = try app.billsCalendar(for: november).items(.bills)

        #expect(items.map(\.date.day) == [1, 10, 12, 16])
        #expect(items.map(\.name) == ["Rent", "Insurance premium", "Society maintenance", "Internet"])
        #expect(items.map(\.detail) == ["Every Month", "Every Month", "Every 3 Months", "Every Month · adds itself"])
        #expect(items.map(\.canAdd) == [true, true, true, false])
        #expect(items.map(\.isAutomatic) == [false, false, false, true])
    }

    @Test func laterRepeatsAppearInLaterMonthsWithoutAnAddButton() throws {
        let app = try background()

        let items = try app.billsCalendar(for: december).items(.bills)

        #expect(items.map(\.name) == ["Rent", "Insurance premium", "Internet"])
        #expect(items.map(\.date.day) == [1, 10, 16])
        #expect(items.allSatisfy { !$0.canAdd })
    }

    @Test func addedAndAutomaticBillsStayOnTheirDay() throws {
        let app = try midNovember()

        let items = try app.billsCalendar(for: november).items(.bills)

        let rent = try #require(items.first { $0.name == "Rent" })
        let internet = try #require(items.first { $0.name == "Internet" })
        #expect(rent.kind == .billAdded)
        #expect(rent.detail == "Added")
        #expect(rent.date == day("2026-11-01"))
        #expect(internet.kind == .billAutoAdded)
        #expect(internet.detail == "Auto-added")
        #expect(internet.date == day("2026-11-16"))
        #expect(items.filter { $0.name == "Rent" }.count == 1)
    }

    @Test func aBillThatHasEndedLeavesTheCalendar() throws {
        let app = try background(rentEnds: "2026-11-30")

        let names = try app.billsCalendar(for: december).items(.bills).map(\.name)

        #expect(!names.contains("Rent"))
    }

    @Test func aOneOffBillReadsOneOff() throws {
        let app = try makeApp()
        try app.addBill(newBill("Passport fee", 1_500, due: "2026-11-05", repeats: .never))

        #expect(try app.billsCalendar(for: november).items(.bills).map(\.detail) == ["One-off"])
    }

    @Test func dotsCountWhatIsDueEachDay() throws {
        let app = try makeApp()
        try app.addBill(newBill("Cash for home", 5_000, due: "2026-11-01"))
        try app.addBill(newBill("Maid's salary", 800, due: "2026-11-01"))
        try app.addBill(newBill("Gym", 2_000, due: "2026-11-05"))

        let calendar = try app.billsCalendar(for: november)

        #expect(calendar.counts(.bills) == [1: 2, 5: 1])
        #expect(calendar.items(.bills, on: 1).map(\.name) == ["Cash for home", "Maid's salary"])
    }

    // MARK: the filter menu

    @Test(arguments: [
        (BillsFilter.allTransactions, ["Rent", "Salary", "Insurance premium", "Society maintenance", "Internet", "RBI bond"]),
        (.bills, ["Rent", "Insurance premium", "Society maintenance", "Internet"]),
        (.notAdded, ["Insurance premium", "Society maintenance"]),
        (.added, ["Rent"]),
        (.autoAdded, ["Internet"]),
        (.income, ["Salary", "RBI bond"]),
        (.upcomingIncome, ["RBI bond"]),
        (.receivedIncome, ["Salary"]),
        (.planned, []),
    ])
    func theFilterMenuNarrowsTheCalendar(filter: BillsFilter, shown: [String]) throws {
        let app = try midNovember()

        let names = try app.billsCalendar(for: november).items(filter).map(\.name)

        #expect(names == shown)
    }

    @Test func anExpectedPayoutSitsOnItsDayAndCanBeRecorded() throws {
        let app = try midNovember()

        let payout = try #require(try app.billsCalendar(for: november).items(.upcomingIncome).first)

        #expect(payout.date == day("2026-11-20"))
        #expect(payout.amount == .rupees(2_000))
        #expect(payout.canRecord)
        #expect(payout.schemeID != nil)
    }

    @Test func onlyTheNextPayoutCanBeRecorded() throws {
        let app = try midNovember()

        let payout = try #require(try app.billsCalendar(for: december).items(.upcomingIncome).first)

        #expect(payout.date == day("2026-12-20"))
        #expect(!payout.canRecord)
    }

    @Test func aRecordedPayoutLeavesUpcomingIncome() throws {
        let app = try midNovember()
        let scheme = try #require(try app.payoutSchemes().schemes.first).scheme
        try app.recordPayout(scheme.id, amount: .rupees(2_000), on: day("2026-11-16"))

        let calendar = try app.billsCalendar(for: november)

        #expect(calendar.items(.upcomingIncome).isEmpty)
        #expect(calendar.items(.receivedIncome).map(\.name) == ["Salary", "RBI bond"])
    }

    @Test func noPayoutIsExpectedAfterTheSchemeMatures() throws {
        let app = try makeApp()
        try app.addScheme(NewPayoutScheme(
            name: "FD", invested: .rupees(50_000), monthlyPayout: .rupees(400), payoutDay: 20,
            maturity: day("2026-11-25")
        ))

        #expect(try app.billsCalendar(for: november).items(.upcomingIncome).count == 1)
        #expect(try app.billsCalendar(for: december).items(.upcomingIncome).isEmpty)
    }

    // MARK: the menu counts

    @Test func theMenuCountsBillsAndPayoutsSeparately() throws {
        let app = try makeApp(today: "2026-11-01")
        try app.addBill(newBill("Rent", 20_000, due: "2026-11-01"))
        try app.addBill(newBill("Insurance", 1_500, due: "2026-11-01", repeats: .never))
        try app.addScheme(NewPayoutScheme(
            name: "RBI bond", invested: .rupees(1_00_000), monthlyPayout: .rupees(2_000), payoutDay: 3, maturity: nil
        ))

        let attention = try app.billsAttention()

        #expect(attention.dueBills == 2)
        #expect(attention.dueIncome == 1)
        #expect(attention.autoAddedUnseen == 0)
        #expect(attention.menuCount == 3)
    }
}
