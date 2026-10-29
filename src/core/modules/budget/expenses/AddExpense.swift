public struct AddExpense: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ new: NewExpense) throws -> Expense {
        try expenses.add(Expense.validated(new, today: clock.today()))
    }
}
