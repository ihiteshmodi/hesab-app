import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/expenses/record-expense.feature and
/// spent-for-and-tags.feature (the parts that need only expenses)
struct ExpenseDetailsTests {
    @Test func anExpenseKeepsItsCategoryEntityWhoItWasForAndTags() throws {
        let app = try makeApp()

        try app.addExpense(NewExpense(
            description: "Train ticket", amount: .rupees(1_200), category: "Transport",
            subCategory: "Train tickets", entity: "IRCTC", spentFor: "Mom", tags: ["Trip", "trip", " Mumbai "]
        ))

        let saved = try #require(try app.monthBudget().expenses.first)
        #expect(saved.category == "Transport")
        #expect(saved.subCategory == "Train tickets")
        #expect(saved.entity == "IRCTC")
        #expect(saved.spentFor == "Mom")
        #expect(saved.tags == ["Trip", "Mumbai"])
    }

    @Test func anExpenseIsForNobodyElseUnlessSaid() throws {
        let app = try makeApp()

        try app.addExpense(NewExpense(description: "Medicines", amount: .rupees(500), category: "Health & Medical"))

        let saved = try #require(try app.monthBudget().expenses.first)
        #expect(saved.spentFor == nil)
        #expect(saved.subCategory == nil)
        #expect(saved.entity == nil)
        #expect(saved.tags.isEmpty)
    }

    @Test func editingAnExpenseChangesWhatIsLeftToSpend() throws {
        let app = try makeApp()
        let expense = try app.addExpense(NewExpense(
            description: "Weekly groceries", amount: .rupees(1_250), category: "Groceries"
        ))
        let before = try app.monthBudget().leftToSpend

        try app.updateExpense(expense.id!, NewExpense(
            description: "Weekly groceries", amount: .rupees(1_350), category: "Groceries"
        ))

        #expect(before - (try app.monthBudget().leftToSpend) == .rupees(100))
        #expect(try app.monthBudget().expenses.count == 1)
    }

    @Test func editingAnExpenseStillRefusesIncompleteInput() throws {
        let app = try makeApp()
        let expense = try app.addExpense(NewExpense(
            description: "Weekly groceries", amount: .rupees(1_250), category: "Groceries"
        ))

        let error = #expect(throws: ExpenseValidationError.self) {
            try app.updateExpense(expense.id!, NewExpense(description: "", amount: .rupees(1_250), category: "Groceries"))
        }

        #expect(error?.message == "Enter a description")
        #expect(try app.monthBudget().expenses.first?.description == "Weekly groceries")
    }

    @Test func editingAnExpenseThatIsGoneIsRefused() throws {
        let app = try makeApp()

        #expect(throws: ExpenseNotFound.self) {
            try app.updateExpense(99, NewExpense(description: "Ghost", amount: .rupees(1), category: "Miscellaneous"))
        }
    }

    @Test func deletingAnExpenseGivesTheMoneyBack() throws {
        let app = try makeApp()
        let expense = try app.addExpense(NewExpense(
            description: "Weekly groceries", amount: .rupees(1_250), category: "Groceries"
        ))

        try app.deleteExpense(expense.id!)

        #expect(try app.monthBudget().expenses.isEmpty)
        #expect(try app.monthBudget().leftToSpend == .zero)
    }

    @Test(arguments: [
        (PaymentMethod.upi, -1_000),
        (PaymentMethod.bank("Visa Card"), -1_000),
        (PaymentMethod.cashWithdrawal, -1_000),
        (PaymentMethod.cash, 0),
        (PaymentMethod.ledger("Mom"), 0),
    ] as [(PaymentMethod, Int)])
    func thePaymentMethodDecidesWhetherLeftToSpendMoves(method: PaymentMethod, change: Int) throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(20_000)))

        try app.addExpense(NewExpense(
            description: "Something", amount: .rupees(1_000), category: "Miscellaneous", paymentMethod: method
        ))

        #expect(try app.monthBudget().leftToSpend == .rupees(20_000 + change))
    }
}
