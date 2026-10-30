import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/planning/planned-expenses.feature
struct PlannedExpenseTests {
    private func appWithTwoItems() throws -> (app: BudgetApp, dental: PlannedItem, helmet: PlannedItem) {
        let app = try makeApp()
        let dental = try app.addPlannedItem(NewPlannedItem(description: "Dental checkup", amount: .rupees(3_000)))
        let helmet = try app.addPlannedItem(NewPlannedItem(description: "Helmet", amount: .rupees(2_000)))
        return (app, dental, helmet)
    }

    @Test func plannedItemsAreListedWithATotalAndNeverTouchLeftToSpend() throws {
        let (app, _, _) = try appWithTwoItems()

        let planned = try app.plannedItems()

        #expect(planned.items.map(\.description) == ["Dental checkup", "Helmet"])
        #expect(planned.total == .rupees(5_000))
        #expect(try app.monthBudget().leftToSpend == .zero)
    }

    @Test func addingAnItemRaisesThePlannedTotal() throws {
        let (app, _, _) = try appWithTwoItems()

        try app.addPlannedItem(NewPlannedItem(description: "Gift", amount: .rupees(1_500)))

        #expect(try app.plannedItems().total == .rupees(6_500))
    }

    @Test(arguments: [
        ("", Money.rupees(1_000) as Money?, "Enter a description"),
        ("  ", Money.rupees(1_000), "Enter a description"),
        ("Gift", Money.zero, "Enter an amount above 0"),
        ("Gift", nil, "Enter an amount above 0"),
    ] as [(String, Money?, String)])
    func anIncompleteItemIsRefusedAndNothingIsSaved(description: String, amount: Money?, message: String) throws {
        let app = try makeApp()

        let error = #expect(throws: PlannedItemError.self) {
            try app.addPlannedItem(NewPlannedItem(description: description, amount: amount))
        }

        #expect(error?.message == message)
        #expect(try app.plannedItems().items.isEmpty)
    }

    @Test func deletingAnItemLowersTheTotal() throws {
        let (app, _, helmet) = try appWithTwoItems()

        try app.deletePlannedItem(helmet.id)

        #expect(try app.plannedItems().total == .rupees(3_000))
        #expect(throws: PlannedItemError.notFound(helmet.id)) { try app.deletePlannedItem(helmet.id) }
    }

    @Test func turningAnItemIntoAnExpenseRemovesItAndLowersLeftToSpend() throws {
        let (app, dental, _) = try appWithTwoItems()

        let expense = try app.addPlannedAsExpense(dental.id, NewExpense(
            description: dental.description, amount: dental.amount, category: "Health & Medical"
        ))

        #expect(expense.date == day("2026-10-30"))
        #expect(try app.plannedItems().items.map(\.description) == ["Helmet"])
        #expect(try app.plannedItems().total == .rupees(2_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(-3_000))
    }

    @Test func theAmountAndDateCanBeChangedWhileAdding() throws {
        let (app, _, helmet) = try appWithTwoItems()

        let expense = try app.addPlannedAsExpense(helmet.id, NewExpense(
            date: day("2026-11-03"), description: "Helmet", amount: .rupees(2_400), category: "Vehicle"
        ))

        #expect(expense.amount == .rupees(2_400))
        #expect(expense.date == day("2026-11-03"))
    }

    @Test func anExpenseThatIsRefusedLeavesTheItemPlanned() throws {
        let (app, dental, _) = try appWithTwoItems()

        #expect(throws: ExpenseValidationError.categoryMissing) {
            try app.addPlannedAsExpense(dental.id, NewExpense(description: "Dental checkup", amount: .rupees(3_000), category: ""))
        }

        #expect(try app.plannedItems().items.count == 2)
        #expect(try app.monthBudget().expenses.isEmpty)
    }

    @Test func anItemThatIsGoneCannotBeTurnedIntoAnExpense() throws {
        let app = try makeApp()

        #expect(throws: PlannedItemError.notFound(9)) {
            try app.addPlannedAsExpense(9, NewExpense(description: "x", amount: .rupees(1), category: "Fuel"))
        }
        #expect(try app.monthBudget().expenses.isEmpty)
        #expect(PlannedItemError.notFound(1).message == "That planned item no longer exists.")
    }
}
