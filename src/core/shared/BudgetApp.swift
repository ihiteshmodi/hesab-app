/// The application interface: screens and tests use the app through these use cases only.
public final class BudgetApp: Sendable {
    public let addExpense: AddExpense
    public let monthBudget: GetMonthBudget

    public init(database: AppDatabase, clock: any DayClock) {
        let expenses = ExpenseRepository(database: database)
        addExpense = AddExpense(expenses: expenses, clock: clock)
        monthBudget = GetMonthBudget(expenses: expenses, clock: clock)
    }
}
