public struct AddExpense: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ new: NewExpense) throws -> Expense {
        try expenses.add(Expense.validated(new, today: clock.today()))
    }
}

public struct UpdateExpense: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ id: Int64, _ new: NewExpense) throws -> Expense {
        let edit = try Expense.validated(new, today: clock.today(), id: id)
        return try expenses.change(id) { try $0.edited(to: edit) }
    }
}

public struct DeleteExpense: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        try expenses.delete(id)
    }
}
