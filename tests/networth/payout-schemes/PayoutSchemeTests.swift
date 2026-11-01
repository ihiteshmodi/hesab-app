import Testing
@testable import HisaabCore

/// Scenarios from tests/networth/payout-schemes/payout-schemes.feature
struct PayoutSchemeTests {
    @discardableResult
    private func scheme(
        _ app: BudgetApp, _ name: String, invested: Int, payout: Int, day payoutDay: Int, maturity: String?
    ) throws -> PayoutScheme {
        try app.addScheme(NewPayoutScheme(
            name: name, invested: .rupees(invested), payoutAmount: .rupees(payout), payoutDay: payoutDay,
            maturity: maturity.map(day)
        ))
    }

    private func background(today: String = "2026-10-30") throws -> (app: BudgetApp, bond: PayoutScheme) {
        let app = try makeApp(today: today)
        let bond = try scheme(app, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: "2027-02-06")
        try scheme(app, "Post scheme", invested: 300_000, payout: 1_850, day: 3, maturity: nil)
        try scheme(app, "Bank FD", invested: 500_000, payout: 3_100, day: 28, maturity: "2027-08-23")
        return (app, bond)
    }

    private func labels(_ app: BudgetApp) throws -> [String] {
        try app.upcomingIncome().map(\.label)
    }

    @Test func totalsAddUpInvestedAndMonthlyPayout() throws {
        let overview = try background().app.payoutSchemes()

        #expect(overview.investedTotal == .rupees(900_000))
        #expect(overview.monthlyPayoutTotal == .rupees(5_750))
    }

    @Test func aMaturityWithinNinetyDaysIsListedAndTheOthersAreNot() throws {
        let (app, _) = try background(today: "2026-12-15")

        let items = try app.upcomingIncome().filter { $0.kind == .maturity }

        #expect(items.map(\.label) == ["Bond A matures in 53 days"])
    }

    @Test func aPayoutInsideTheAlertWindowIsListedWithItsApproximateAmount() throws {
        let (app, _) = try background(today: "2026-11-20")
        try app.updatePreferences { $0.payoutAlertDays = 5 }

        let payouts = try app.upcomingIncome().filter { $0.kind == .payout }

        #expect(payouts.map(\.label) == ["Bond A payout expected 24 Nov, about 800"])
    }

    @Test func recordingShowsAConfirmationAndCreatesInvestmentIncome() throws {
        let (app, bond) = try background(today: "2026-11-24")

        let draft = try app.payoutDraft(bond.id)
        #expect(draft.date == day("2026-11-24"))
        #expect(draft.amount == .rupees(800))
        #expect(draft.note == "on the expected date")

        let entry = try app.recordPayout(bond.id, amount: .rupees(790), on: draft.date)

        #expect(entry.kind == .investmentIncome)
        #expect(entry.amount == .rupees(790))
        #expect(entry.date == day("2026-11-24"))
        #expect(entry.note == "Bond A")
        #expect(try app.upcomingIncome().contains { $0.label.hasPrefix("Bond A payout expected 24 Nov") } == false)
    }

    @Test(arguments: [
        ("2026-11-23", "1 day earlier than expected"),
        ("2026-11-24", "on the expected date"),
        ("2026-11-25", "1 day later than expected"),
        ("2026-11-21", "3 days earlier than expected"),
    ])
    func aPayoutCanArriveEarlyOrLate(today: String, note: String) throws {
        let (app, bond) = try background(today: today)

        let draft = try app.payoutDraft(bond.id)

        #expect(draft.date == day(today))
        #expect(draft.note == note)
    }

    @Test func theConfirmationCanChangeTheDate() throws {
        let (app, bond) = try background(today: "2026-11-25")

        let entry = try app.recordPayout(bond.id, amount: .rupees(800), on: day("2026-11-24"))

        #expect(entry.date == day("2026-11-24"))
    }

    @Test func notConfirmingRecordsNothing() throws {
        let (app, bond) = try background(today: "2026-11-24")

        _ = try app.payoutDraft(bond.id)

        #expect(try app.monthBudget().incomeEntries.isEmpty)
        #expect(try labels(app).contains("Bond A payout expected 24 Nov, about 800"))
    }

    @Test(arguments: [nil, Money.zero] as [Money?])
    func aConfirmationAmountMustBeAboveZero(amount: Money?) throws {
        let (app, bond) = try background(today: "2026-11-24")

        let error = #expect(throws: PayoutSchemeError.self) { try app.recordPayout(bond.id, amount: amount, on: day("2026-11-24")) }

        #expect(error?.message == "Enter an amount above 0")
        #expect(try app.monthBudget().incomeEntries.isEmpty)
    }

    @Test func aMaturedSchemeAsksToBeClosedAndClosingUpdatesTheTotals() throws {
        let (app, bond) = try background(today: "2027-02-07")
        #expect(try labels(app).contains("Bond A matured 1 day ago"))

        let closed = try app.closeScheme(bond.id)

        let overview = try app.payoutSchemes()
        #expect(overview.investedTotal == .rupees(800_000))
        #expect(overview.monthlyPayoutTotal == .rupees(4_950))
        #expect(overview.schemes.contains { $0.scheme.name == "Bond A" && $0.scheme.isClosed })
        #expect(try labels(app).contains { $0.contains("matured") } == false)
        #expect(closed.reminder == "Update your bank balance")
    }

    @Test func addingASchemeRaisesTheTotals() throws {
        let (app, _) = try background()

        try scheme(app, "Bond B", invested: 50_000, payout: 410, day: 26, maturity: "2028-08-26")

        let overview = try app.payoutSchemes()
        #expect(overview.investedTotal == .rupees(950_000))
        #expect(overview.monthlyPayoutTotal == .rupees(6_160))
    }

    @Test(arguments: [
        ("", Money.rupees(1_000) as Money?, Money.rupees(10) as Money?, "Enter a name"),
        ("Bond C", Money.zero, Money.rupees(10), "Enter an amount above 0"),
        ("Bond C", nil, Money.rupees(10), "Enter an amount above 0"),
        ("Bond C", Money.rupees(1_000), Money.rupees(-1), "Enter a payout of 0 or more"),
        ("Bond C", Money.rupees(1_000), nil, "Enter a payout of 0 or more"),
    ] as [(String, Money?, Money?, String)])
    func invalidSchemesAreRejected(name: String, invested: Money?, payout: Money?, message: String) throws {
        let app = try makeApp()

        let error = #expect(throws: PayoutSchemeError.self) {
            try app.addScheme(NewPayoutScheme(name: name, invested: invested, payoutAmount: payout, payoutDay: 5, maturity: nil))
        }

        #expect(error?.message == message)
    }

    @Test func aPayoutDayMustBeADayOfTheMonth() throws {
        let app = try makeApp()

        #expect(throws: PayoutSchemeError.payoutDayInvalid) {
            try app.addScheme(NewPayoutScheme(name: "X", invested: .rupees(1), payoutAmount: .rupees(1), payoutDay: 32, maturity: nil))
        }
        #expect(PayoutSchemeError.payoutDayInvalid.message == "Enter a payout day between 1 and 31")
        #expect(PayoutSchemeError.notFound(1).message == "That scheme no longer exists.")
    }

    @Test func aPayoutDayBeyondAShortMonthFallsOnItsLastDay() throws {
        let app = try makeApp(today: "2027-02-25")
        try scheme(app, "Late", invested: 1_000, payout: 100, day: 31, maturity: nil)

        #expect(try labels(app) == ["Late payout expected 28 Feb, about 100"])
    }

    @Test func nothingComingUpShowsNothing() throws {
        let app = try makeApp()

        #expect(try app.upcomingIncome().isEmpty)
    }

    // MARK: the count on the Bills tab

    @Test(arguments: [(false, 0, 1), (true, 0, 0), (false, 1, 2)])
    func theBillsTabCountsWhatNeedsAttention(recorded: Bool, matured: Int, badge: Int) throws {
        let app = try makeApp(today: "2026-11-24")
        let bond = try scheme(app, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: nil)
        if recorded { try app.recordPayout(bond.id, amount: .rupees(800), on: day("2026-11-24")) }
        if matured == 1 { try scheme(app, "Old", invested: 1_000, payout: 0, day: 1, maturity: "2026-11-01") }

        #expect(try app.billsAttention().badge == badge)
    }

    @Test func payoutsOutsideTheAlertWindowDoNotCount() throws {
        let app = try makeApp(today: "2026-11-17")
        try scheme(app, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: nil)

        #expect(try app.billsAttention().badge == 0)
        #expect(try app.billsAttention().menuCount == 0)
    }

    @Test func aZeroDayAlertCountsOnlyOnThePayoutDay() throws {
        let before = try makeApp(today: "2026-11-23")
        try before.updatePreferences { $0.payoutAlertDays = 0 }
        try scheme(before, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: nil)
        let onDay = try makeApp(today: "2026-11-24")
        try onDay.updatePreferences { $0.payoutAlertDays = 0 }
        try scheme(onDay, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: nil)

        #expect(try before.billsAttention().badge == 0)
        #expect(try onDay.billsAttention().badge == 1)
    }

    @Test func aPayoutInsideItsAlertWindowAlsoCountsInTheMenu() throws {
        let app = try makeApp(today: "2026-11-24")
        try scheme(app, "Bond A", invested: 100_000, payout: 800, day: 24, maturity: nil)

        #expect(try app.billsAttention().menuCount == 1)
    }

    // MARK: editing

    @Test func priyaEditsASchemeAndItsRecordedPayoutsAreKept() throws {
        let (app, bond) = try background()
        try app.recordPayout(bond.id, amount: .rupees(800), on: day("2026-10-24"))

        try app.updateScheme(bond.id, NewPayoutScheme(
            name: "Bond A", invested: .rupees(100_000), payoutAmount: .rupees(850), payoutDay: 26,
            maturity: day("2027-03-10")
        ))

        let edited = try #require(try app.payoutSchemes().schemes.first { $0.scheme.id == bond.id }).scheme
        #expect(edited.maturity == day("2027-03-10"))
        #expect(edited.payoutAmount == .rupees(850))
        #expect(edited.payoutDay == 26)
        #expect(try app.payoutDraft(bond.id).expectedDate == day("2026-11-26"))
    }

    @Test func anEditedSchemeIsCheckedLikeANewOne() throws {
        let (app, bond) = try background()

        #expect(throws: PayoutSchemeError.amountMissingOrZero) {
            try app.updateScheme(bond.id, NewPayoutScheme(
                name: "Bond A", invested: .zero, payoutAmount: .rupees(800), payoutDay: 24, maturity: nil
            ))
        }
        #expect(try app.payoutSchemes().schemes.first { $0.scheme.id == bond.id }?.scheme.invested == .rupees(100_000))
    }

    private func periodic(
        _ app: BudgetApp, every frequency: PayoutFrequency, amount: Int, first: String, day payoutDay: Int
    ) throws -> PayoutScheme {
        try app.addScheme(NewPayoutScheme(
            name: "FD", invested: .rupees(100_000), payoutAmount: .rupees(amount), payoutDay: payoutDay,
            maturity: nil, frequency: frequency, firstPayout: day(first)
        ))
    }

    @Test(arguments: [PayoutFrequency.monthly, .quarterly, .halfYearly, .yearly])
    func aSchemeIsExpectedOnItsFirstPayoutWhateverItsPace(frequency: PayoutFrequency) throws {
        let app = try makeApp(today: "2026-12-06")
        let fd = try periodic(app, every: frequency, amount: 1_000, first: "2026-12-10", day: 10)

        #expect(try app.payoutDraft(fd.id).expectedDate == day("2026-12-10"))
        #expect(try labels(app) == ["FD payout expected 10 Dec, about 1,000"])
    }

    @Test(arguments: [(PayoutFrequency.monthly, "2027-01-10"), (.quarterly, "2027-03-10"), (.halfYearly, "2027-06-10"), (.yearly, "2027-12-10")])
    func afterARecordedPayoutTheNextOneIsOnePaceLater(frequency: PayoutFrequency, next: String) throws {
        let app = try makeApp(today: "2026-12-10")
        let fd = try periodic(app, every: frequency, amount: 1_000, first: "2026-12-10", day: 10)

        try app.recordPayout(fd.id, amount: .rupees(1_000), on: day("2026-12-10"))

        #expect(try app.payoutDraft(fd.id).expectedDate == day(next))
    }

    @Test func aSchemeWhoseFirstPayoutIsInTheFutureWaitsForIt() throws {
        let app = try makeApp(today: "2026-10-30")
        let fd = try periodic(app, every: .monthly, amount: 1_000, first: "2026-12-24", day: 24)

        #expect(try app.payoutDraft(fd.id).expectedDate == day("2026-12-24"))
        #expect(try labels(app).isEmpty)
    }

    @Test func theMonthlyPayoutTotalIsTheMonthlyEquivalent() throws {
        let app = try makeApp()
        try periodic(app, every: .monthly, amount: 1_000, first: "2026-11-05", day: 5)
        try periodic(app, every: .quarterly, amount: 3_000, first: "2026-11-05", day: 5)
        try periodic(app, every: .yearly, amount: 12_000, first: "2026-11-05", day: 5)

        #expect(try app.payoutSchemes().monthlyPayoutTotal == .rupees(3_000))
    }

    @Test func aQuarterlySchemeAppearsOnTheCalendarOnlyInItsMonths() throws {
        let app = try makeApp(today: "2026-10-30")
        try periodic(app, every: .quarterly, amount: 3_000, first: "2026-12-10", day: 10)
        func payouts(_ month: CalendarDate.YearMonth) throws -> Int {
            try app.billsCalendar(for: month).items(.upcomingIncome).count
        }

        #expect(try payouts(.init(year: 2026, month: 11)) == 0)
        #expect(try payouts(.init(year: 2026, month: 12)) == 1)
        #expect(try payouts(.init(year: 2027, month: 1)) == 0)
        #expect(try payouts(.init(year: 2027, month: 3)) == 1)
    }

    @Test func theLastDayOfEveryMonthSuitsShortAndLongMonths() throws {
        let app = try makeApp(today: "2027-02-20")
        let fd = try periodic(app, every: .monthly, amount: 500, first: "2027-01-31", day: 31)

        #expect(try app.payoutDraft(fd.id).expectedDate == day("2027-02-28"))
        try app.recordPayout(fd.id, amount: .rupees(500), on: day("2027-02-28"))
        #expect(try app.payoutDraft(fd.id).expectedDate == day("2027-03-31"))
    }

    @Test func thePaceAndFirstPayoutAreKeptAndCanBeEdited() throws {
        let app = try makeApp()
        let fd = try periodic(app, every: .quarterly, amount: 3_000, first: "2026-12-10", day: 10)

        try app.updateScheme(fd.id, NewPayoutScheme(
            name: "FD", invested: .rupees(100_000), payoutAmount: .rupees(6_000), payoutDay: 12,
            maturity: nil, frequency: .halfYearly, firstPayout: day("2027-01-12")
        ))

        let edited = try #require(try app.payoutSchemes().schemes.first { $0.scheme.id == fd.id }).scheme
        #expect(edited.frequency == .halfYearly)
        #expect(edited.firstPayout == day("2027-01-12"))
    }
}

