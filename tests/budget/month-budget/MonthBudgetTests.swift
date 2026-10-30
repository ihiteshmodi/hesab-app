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
        #expect(october.hasNoEntriesAtAll)
    }

    @Test func leftToSpendIsEverythingInMinusSavingsAndSpending() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(150_000)))
        try app.addIncome(NewIncome(kind: .investmentIncome, amount: .rupees(20_000)))
        try app.addIncome(NewIncome(kind: .savings, amount: .rupees(100_000)))
        try app.addExpense(NewExpense(description: "Month so far", amount: .rupees(35_000), category: "Home & Utilities"))

        #expect(try app.monthBudget().leftToSpend == .rupees(35_000))
        #expect(try app.monthBudget().hasNoEntriesAtAll == false)
    }

    @Test func salaryDayAddsMoneyAndNextMonthsExpensesLowerItStraightAway() throws {
        let app = try makeApp(today: "2026-10-30")
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(5_000)))

        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(150_000)))
        try app.addIncome(NewIncome(kind: .savings, amount: .rupees(100_000)))
        try app.addExpense(NewExpense(
            date: day("2026-11-01"), description: "Rent", amount: .rupees(20_000), category: "Home & Utilities"
        ))
        try app.addExpense(NewExpense(
            date: day("2026-11-10"), description: "Bill", amount: .rupees(2_000), category: "Home & Utilities"
        ))

        let november = try app.monthBudget(for: CalendarDate.YearMonth(year: 2026, month: 11))
        #expect(try app.monthBudget().leftToSpend == .rupees(33_000))
        #expect(november.spentThisMonth == .rupees(22_000))
    }

    @Test func cashAndLedgerSpendingDoNotChangeLeftToSpendOrSpentThisMonth() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(35_000)))

        try app.addExpense(NewExpense(
            description: "Chai", amount: .rupees(500), category: "Food & Dining", paymentMethod: .cash
        ))
        try app.addExpense(NewExpense(
            description: "Repairs", amount: .rupees(4_000), category: "Home & Utilities", paymentMethod: .ledger("Neighbor")
        ))

        let october = try app.monthBudget()
        #expect(october.leftToSpend == .rupees(35_000))
        #expect(october.spentThisMonth == .zero)
        #expect(october.expenses.count == 2)
    }

    @Test func incomeIsListedOnlyInItsOwnMonthNewestFirst() throws {
        let app = try makeApp(today: "2026-10-30")
        try app.addIncome(NewIncome(date: day("2026-09-30"), kind: .salary, amount: .rupees(100_000), note: "September"))
        try app.addIncome(NewIncome(date: day("2026-10-30"), kind: .salary, amount: .rupees(150_000), note: "October"))

        let october = try app.monthBudget()

        #expect(october.incomeEntries.map(\.note) == ["October"])
        #expect(october.incomeThisMonth == .rupees(150_000))
        #expect(october.leftToSpend == .rupees(250_000))
    }
}
