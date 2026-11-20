import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/month-budget/cash-forecast.feature
struct CashForecastTests {
    /// Today is 2026-11-20 with 100,000 in hand unless said otherwise.
    private func app(today: String = "2026-11-20", income: Int = 100_000) throws -> BudgetApp {
        let app = try makeApp(today: today)
        try app.addIncome(NewIncome(date: day("2026-07-01"), kind: .salary, amount: .rupees(income)))
        return app
    }

    @discardableResult
    private func bill(
        _ app: BudgetApp, _ name: String, _ rupees: Int, due: String, repeats: BillRepeat = .monthly, method: PaymentMethod = .upi
    ) throws -> Bill {
        try app.addBill(NewBill(
            name: name, amount: .rupees(rupees), category: "Home & Utilities", paymentMethod: method, dueDate: day(due), repeats: repeats
        ))
    }

    @Test func aBillComesOffOnItsDueDate() throws {
        let app = try app()
        try bill(app, "Rent", 10_000, due: "2026-11-25", repeats: .never)

        let forecast = try app.cashForecast()

        #expect(forecast.points.count == 31)
        #expect(forecast.points[4] == .rupees(100_000))
        #expect(forecast.points[5] == .rupees(90_000))
        #expect(forecast.points.last == .rupees(90_000))
        #expect(forecast.billsOut == .rupees(10_000))
        #expect(forecast.lowest == .rupees(90_000))
        #expect(forecast.lowestDay == 5)
    }

    @Test func onlyDueDatesInsideTheWindowCount() throws {
        let app = try app()
        try bill(app, "Rent", 10_000, due: "2026-11-25")

        #expect(try app.cashForecast().billsOut == .rupees(10_000))
    }

    @Test func aRepeatingBillThatFallsSeveralTimesCountsEachTime() throws {
        let app = try app()
        try bill(app, "Gym", 1_000, due: "2026-11-21", repeats: .weekly)

        let forecast = try app.cashForecast()

        #expect(forecast.billsOut == .rupees(5_000))
        #expect(forecast.points[0] == .rupees(100_000))
        #expect(forecast.points[1] == .rupees(99_000))
        #expect(forecast.points[8] == .rupees(98_000))
    }

    @Test func aPastDueBillThatIsNotAddedComesOffToday() throws {
        let app = try app()
        try bill(app, "Internet", 800, due: "2026-11-15", repeats: .never)

        #expect(try app.cashForecast().points[0] == .rupees(99_200))
    }

    @Test func billsPaidInCashDoNotChangeLeftToSpend() throws {
        let app = try app()
        try bill(app, "Maid", 800, due: "2026-11-25", method: .cash)

        let forecast = try app.cashForecast()

        #expect(forecast.billsOut == .zero)
        #expect(forecast.points.allSatisfy { $0 == .rupees(100_000) })
    }

    @Test func usualDailySpendingComesOffEveryDay() throws {
        let app = try app(income: 100_000)
        try app.addExpense(NewExpense(date: day("2026-08-10"), description: "Groceries", amount: .rupees(9_200), category: "Groceries"))

        let forecast = try app.cashForecast()

        #expect(forecast.dailySpend == .rupees(100))
        #expect(forecast.points[0] == .rupees(90_800))
        #expect(forecast.points[10] == .rupees(89_800))
    }

    @Test func spendingThatCameFromBillsIsNotUsualDailySpending() throws {
        let app = try app()
        let rent = try bill(app, "Rent", 5_000, due: "2026-10-25")
        try app.addBillOccurrence(rent.id, try #require(try app.billDraft(rent.id)))

        #expect(try app.cashForecast().dailySpend == .zero)
    }

    @Test func anExpectedPayoutGoesOnItsDate() throws {
        let app = try app()
        try app.addScheme(NewPayoutScheme(
            name: "Post office", invested: .rupees(300_000), payoutAmount: .rupees(1_850), payoutDay: 25, maturity: nil
        ))

        let forecast = try app.cashForecast()

        #expect(forecast.points[4] == .rupees(100_000))
        #expect(forecast.points[5] == .rupees(101_850))
        #expect(forecast.payoutsIn == .rupees(1_850))
    }

    @Test func aPayoutThatHerLastOneSentToSavingsIsLeftOut() throws {
        let app = try app(today: "2026-10-20")
        let scheme = try app.addScheme(NewPayoutScheme(
            name: "Post office", invested: .rupees(300_000), payoutAmount: .rupees(1_850), payoutDay: 25, maturity: nil
        ))
        try app.recordPayout(scheme.id, amount: .rupees(1_850), on: day("2026-10-25"), toSavings: true)

        #expect(try app.cashForecast(days: 40).payoutsIn == .zero)
    }

    @Test func aPayoutThatHerLastOneAddedToLeftToSpendIsKept() throws {
        let app = try app(today: "2026-10-20")
        let scheme = try app.addScheme(NewPayoutScheme(
            name: "Post office", invested: .rupees(300_000), payoutAmount: .rupees(1_850), payoutDay: 25, maturity: nil
        ))
        try app.recordPayout(scheme.id, amount: .rupees(1_850), on: day("2026-10-25"))

        #expect(try app.cashForecast(days: 40).payoutsIn == .rupees(1_850))
    }

    @Test func theLineCanGoBelowZero() throws {
        let app = try app(income: 5_000)
        try bill(app, "Fees", 8_000, due: "2026-11-27", repeats: .never)

        let forecast = try app.cashForecast()

        #expect(forecast.lowest == .rupees(-3_000))
        #expect(forecast.lowestDay == 7)
    }

    @Test func withNothingSetUpTheLineIsFlat() throws {
        let forecast = try app().cashForecast()

        #expect(forecast.points.allSatisfy { $0 == .rupees(100_000) })
        #expect(forecast.lowestDay == 0)
    }
}
