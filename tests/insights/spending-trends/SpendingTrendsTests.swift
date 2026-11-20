import Testing
@testable import HisaabCore

/// Scenarios from tests/insights/spending-trends/spending-trends.feature
struct SpendingTrendsTests {
    private let november = CalendarDate.YearMonth(year: 2026, month: 11)
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    @discardableResult
    private func spend(
        _ app: BudgetApp, _ rupees: Int, on date: String, category: String = "Food & Dining"
    ) throws -> Expense {
        try app.addExpense(NewExpense(date: day(date), description: "Item", amount: .rupees(rupees), category: category))
    }

    private func app() throws -> BudgetApp { try makeApp(today: "2026-11-20") }

    // MARK: this month against last month

    @Test func runningSpendThisMonthRunsToTodayAndLastMonthRunsItsWholeLength() throws {
        let app = try app()
        try spend(app, 100, on: "2026-10-05")
        try spend(app, 200, on: "2026-10-25")
        try spend(app, 150, on: "2026-11-03")
        try spend(app, 50, on: "2026-11-18")

        let pace = try app.spendingPace()

        #expect(pace.upToDay == 20)
        #expect(pace.thisMonth.count == 20)
        #expect(pace.thisMonth[1] == .zero)
        #expect(pace.thisMonth[2] == .rupees(150))
        #expect(pace.thisMonth.last == .rupees(200))
        #expect(pace.lastMonth.count == 31)
        #expect(pace.lastMonth[4] == .rupees(100))
        #expect(pace.lastMonth.last == .rupees(300))
        #expect(pace.lastMonthAtSameDay == .rupees(100))
        #expect(pace.difference == .rupees(100))
    }

    @Test func anEarlierMonthIsComparedOverItsWholeLengthWithTheShorterMonthBefore() throws {
        let app = try app()
        try spend(app, 400, on: "2026-09-30")
        try spend(app, 100, on: "2026-10-31")

        let pace = try app.spendingPace(for: october)

        #expect(pace.upToDay == 31)
        #expect(pace.thisMonth.count == 31)
        #expect(pace.lastMonth.count == 30)
        #expect(pace.lastMonthAtSameDay == .rupees(400))
        #expect(pace.difference == .rupees(-300))
    }

    @Test func refundedMoneyDoesNotCountAsSpent() throws {
        let app = try app()
        let order = try spend(app, 600, on: "2026-11-05")
        try app.markRefundable(order.id!)
        try app.recordReceived(order.id!, .rupees(600))

        #expect(try app.spendingPace().thisMonth.last == .zero)
    }

    // MARK: income against spent

    @Test func eachMonthShowsIncomeSpentAndTheShareKept() throws {
        let app = try app()
        try app.addIncome(NewIncome(date: day("2026-10-01"), kind: .salary, amount: .rupees(100_000)))
        try spend(app, 40_000, on: "2026-10-12")

        let trend = try app.monthlyTrend()

        #expect(trend.map(\.month) == (6...11).map { CalendarDate.YearMonth(year: 2026, month: $0) })
        let last = try #require(trend.first { $0.month == october })
        #expect(last.income == .rupees(100_000))
        #expect(last.spent == .rupees(40_000))
        #expect(last.savingsRatePercent == 60)
        #expect(!last.isInProgress)
    }

    @Test func theMonthStillRunningShowsNoPercentage() throws {
        let app = try app()
        try app.addIncome(NewIncome(date: day("2026-11-01"), kind: .salary, amount: .rupees(100_000)))

        let current = try #require(try app.monthlyTrend().last)

        #expect(current.isInProgress)
        #expect(current.savingsRatePercent == nil)
    }

    @Test func aMonthWithNoIncomeShowsNoPercentage() throws {
        let app = try app()
        try spend(app, 500, on: "2026-10-03")

        #expect(try app.monthlyTrend().first { $0.month == october }?.savingsRatePercent == nil)
    }

    @Test func movesIntoSavingsAreNotIncomeButIncomeAddedToSavingsIs() throws {
        let app = try app()
        try app.addIncome(NewIncome(date: day("2026-10-02"), kind: .savings, amount: .rupees(10_000)))
        try app.addIncome(NewIncome(date: day("2026-10-03"), kind: .investmentIncome, amount: .rupees(800), toSavings: true))

        #expect(try app.monthlyTrend().first { $0.month == october }?.income == .rupees(800))
    }

    @Test func theTrendEndsAtTheMonthAskedFor() throws {
        let app = try app()

        let trend = try app.monthlyTrend(endingAt: october, months: 3)

        #expect(trend.map(\.month.month) == [8, 9, 10])
        #expect(trend.allSatisfy { !$0.isInProgress })
    }

    // MARK: spending against normal

    @Test func aCategoryReadsAboveUsualAgainstTheAverageOfTheSameDaysInThe3EarlierMonths() throws {
        let app = try app()
        for month in ["08", "09", "10"] {
            try spend(app, 2_000, on: "2026-\(month)-10")
            try spend(app, 9_000, on: "2026-\(month)-25")
        }
        try spend(app, 5_000, on: "2026-11-12")

        let normal = try app.spendingVsNormal()

        #expect(normal.hasHistory)
        #expect(normal.changes == [CategoryChange(category: "Food & Dining", thisMonth: .rupees(5_000), usual: .rupees(2_000))])
        #expect(normal.changes.first?.difference == .rupees(3_000))
    }

    @Test func aCategoryNotSpentOnThisMonthReadsBelowUsual() throws {
        let app = try app()
        for month in ["08", "09", "10"] { try spend(app, 1_000, on: "2026-\(month)-05", category: "Fuel") }

        let change = try #require(try app.spendingVsNormal().changes.first)

        #expect(change.category == "Fuel")
        #expect(change.difference == .rupees(-1_000))
    }

    @Test func onlyTheSixBiggestMovesAreListedBiggestFirst() throws {
        let app = try app()
        let categories = ["Fuel", "Food & Dining", "Transport", "Groceries", "Insurance", "Vehicle", "Lifestyle", "Fitness"]
        for month in ["08", "09", "10"] { try spend(app, 100, on: "2026-\(month)-01", category: "Fuel") }
        for (index, category) in categories.enumerated() { try spend(app, 1_000 * (index + 1), on: "2026-11-02", category: category) }

        let changes = try app.spendingVsNormal().changes

        #expect(changes.count == 6)
        #expect(changes.first?.category == "Fitness")
        #expect(changes.map(\.category).contains("Food & Dining") == false)
    }

    @Test func withoutThreeMonthsOfHistoryNothingIsListed() throws {
        let app = try app()
        try spend(app, 500, on: "2026-10-05")
        try spend(app, 900, on: "2026-11-05")

        let normal = try app.spendingVsNormal()

        #expect(!normal.hasHistory)
        #expect(normal.changes.isEmpty)
    }

    // MARK: trend on each category

    @Test func eachCategoryGetsSixMonthlyAmountsOldestFirstAndIsRisingWhen25PercentAboveUsual() throws {
        let app = try app()
        for (month, rupees) in [("06", 900), ("07", 1_000), ("08", 1_000), ("09", 1_000), ("10", 1_000)] {
            try spend(app, rupees, on: "2026-\(month)-05")
        }
        try spend(app, 1_300, on: "2026-11-05")

        let food = try #require(try app.categoryTrends().first { $0.category == "Food & Dining" })

        #expect(food.values == [900, 1_000, 1_000, 1_000, 1_000, 1_300].map { .rupees($0) })
        #expect(food.isRising)
    }

    @Test func aSteadyCategoryIsNotRising() throws {
        let app = try app()
        for month in ["08", "09", "10", "11"] { try spend(app, 1_000, on: "2026-\(month)-05") }

        #expect(try app.categoryTrends().first?.isRising == false)
    }

    @Test func aNewCategoryIsNotCalledRising() throws {
        let app = try app()
        try spend(app, 1_000, on: "2026-11-05", category: "Pets")

        #expect(try app.categoryTrends().first { $0.category == "Pets" }?.isRising == false)
    }
}
