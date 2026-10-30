/// The application interface: screens and tests use the app through these use cases only.
public final class BudgetApp: Sendable {
    public let addExpense: AddExpense
    public let updateExpense: UpdateExpense
    public let deleteExpense: DeleteExpense
    public let markRefundable: MarkRefundable
    public let recordReceived: RecordReceived
    public let undoSettlement: UndoSettlement
    public let unmarkRefundable: UnmarkRefundable
    public let pendingRefunds: GetPendingRefunds
    public let addIncome: AddIncome
    public let deleteIncome: DeleteIncome
    public let monthBudget: GetMonthBudget

    public init(database: AppDatabase, clock: any DayClock) {
        let expenses = ExpenseRepository(database: database)
        let income = IncomeRepository(database: database)
        addExpense = AddExpense(expenses: expenses, clock: clock)
        updateExpense = UpdateExpense(expenses: expenses, clock: clock)
        deleteExpense = DeleteExpense(expenses: expenses)
        markRefundable = MarkRefundable(expenses: expenses)
        recordReceived = RecordReceived(expenses: expenses)
        undoSettlement = UndoSettlement(expenses: expenses)
        unmarkRefundable = UnmarkRefundable(expenses: expenses)
        pendingRefunds = GetPendingRefunds(expenses: expenses)
        addIncome = AddIncome(income: income, clock: clock)
        deleteIncome = DeleteIncome(income: income)
        monthBudget = GetMonthBudget(expenses: expenses, income: income, clock: clock)
    }
}
