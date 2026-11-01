import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/expenses/record-expense.feature
struct RecordExpenseTests {
    @Test func addingAnExpenseListsItInItsMonthAndLowersLeftToSpend() throws {
        let app = try makeApp(today: "2026-10-30")
        let before = try app.monthBudget().leftToSpend

        try app.addExpense(NewExpense(
            description: "Weekly groceries", amount: .rupees(1250), category: "Home & Utilities"
        ))

        let october = try app.monthBudget()
        #expect(october.expenses.map(\.description) == ["Weekly groceries"])
        #expect(october.expenses.first?.date == day("2026-10-30"))
        #expect(before - october.leftToSpend == .rupees(1250))
    }

    @Test func anExpenseWithAFutureDateCountsAtOnceAndAppearsInThatMonth() throws {
        let app = try makeApp(today: "2026-10-30")

        try app.addExpense(NewExpense(
            date: day("2026-11-10"), description: "Rent", amount: .rupees(20_000), category: "Home & Utilities"
        ))

        let november = CalendarDate.YearMonth(year: 2026, month: 11)
        #expect(try app.monthBudget().expenses.isEmpty)
        #expect(try app.monthBudget(for: november).expenses.map(\.description) == ["Rent"])
        #expect(try app.monthBudget().leftToSpend == .rupees(-20_000))
    }

    @Test(arguments: [
        (nil, "Weekly groceries", "Home & Utilities", "Enter an amount above 0"),
        (Money.zero, "Weekly groceries", "Home & Utilities", "Enter an amount above 0"),
        (Money.rupees(-50), "Weekly groceries", "Home & Utilities",
         "Enter an amount above 0. To record money received, add it under Income."),
        (Money.rupees(1000), "", "Home & Utilities", "Enter a description"),
        (Money.rupees(1000), "Weekly groceries", "", "Choose a category"),
    ] as [(Money?, String, String, String)])
    func anIncompleteExpenseIsRefusedWithAHelpfulMessageAndNothingIsSaved(
        amount: Money?, description: String, category: String, message: String
    ) throws {
        let app = try makeApp()

        let error = #expect(throws: ExpenseValidationError.self) {
            try app.addExpense(NewExpense(description: description, amount: amount, category: category))
        }

        #expect(error?.message == message)
        #expect(try app.monthBudget().expenses.isEmpty)
    }

    // MARK: notes

    private func expenseWithNote(_ app: BudgetApp, _ note: String) throws -> Expense {
        try app.addExpense(NewExpense(
            date: day("2026-10-12"), description: "Gadget", amount: .rupees(549), category: "Shopping - Wants", notes: note
        ))
    }

    @Test func aNoteIsKeptAndTrimmedWhenAnExpenseIsAdded() throws {
        let app = try makeApp()

        let saved = try expenseWithNote(app, "  used coupon THANKYOU ")

        #expect(try app.monthBudget(for: .init(year: 2026, month: 10)).expenses.first { $0.id == saved.id }?.notes == "used coupon THANKYOU")
    }

    @Test func aNoteCanBeChangedWhileEditing() throws {
        let app = try makeApp()
        let saved = try expenseWithNote(app, "used coupon THANKYOU")

        try app.updateExpense(saved.id ?? 0, NewExpense(
            date: day("2026-10-12"), description: "Gadget", amount: .rupees(549), category: "Shopping - Wants", notes: "coupon gave 50 off"
        ))

        #expect(try app.monthBudget(for: .init(year: 2026, month: 10)).expenses.first?.notes == "coupon gave 50 off")
    }
}
