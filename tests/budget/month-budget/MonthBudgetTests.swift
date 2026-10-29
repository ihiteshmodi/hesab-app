import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/month-budget/month-budget.feature (the ones that need only expenses)
struct MonthBudgetTests {
    @Test func spentThisMonthCoversOnlyTheViewedMonthWhileLeftToSpendCoversEverything() throws {
        let app = try makeApp(today: "2026-10-30")
        try app.addExpense(NewExpense(
            date: day("2026-09-15"), description: "September bills", amount: .rupees(23_000), category: "Home & Utilities"
        ))
        try app.addExpense(NewExpense(
            date: day("2026-10-12"), description: "October bills", amount: .rupees(12_000), category: "Home & Utilities"
        ))

        let october = try app.monthBudget()

        #expect(october.spentThisMonth == .rupees(12_000))
        #expect(october.leftToSpend == .rupees(-35_000))
    }

    @Test func switchingTheMonthShowsThatMonthsSpending() throws {
        let app = try makeApp(today: "2026-10-30")
        try app.addExpense(NewExpense(
            date: day("2026-09-15"), description: "September bills", amount: .rupees(23_000), category: "Home & Utilities"
        ))

        let september = try app.monthBudget(for: CalendarDate.YearMonth(year: 2026, month: 9))

        #expect(september.spentThisMonth == .rupees(23_000))
        #expect(september.expenses.map(\.description) == ["September bills"])
    }

    @Test func theNewestExpenseComesFirstWithinAMonth() throws {
        let app = try makeApp(today: "2026-10-30")
        for (date, name) in [("2026-10-03", "Early"), ("2026-10-27", "Late"), ("2026-10-12", "Middle")] {
            try app.addExpense(NewExpense(
                date: day(date), description: name, amount: .rupees(100), category: "Home & Utilities"
            ))
        }

        #expect(try app.monthBudget().expenses.map(\.description) == ["Late", "Middle", "Early"])
    }

    @Test func nothingRecordedShowsZero() throws {
        let app = try makeApp()

        let october = try app.monthBudget()

        #expect(october.leftToSpend == .zero)
        #expect(october.spentThisMonth == .zero)
        #expect(october.expenses.isEmpty)
    }
}
