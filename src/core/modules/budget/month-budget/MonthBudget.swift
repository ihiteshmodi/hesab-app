public struct MonthBudget: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    public let leftToSpend: Money
    public let spentThisMonth: Money
    /// Newest first.
    public let expenses: [Expense]

    init(allExpenses: [Expense], month: CalendarDate.YearMonth) {
        let inMonth = allExpenses
            .filter { $0.date.yearMonth == month }
            .sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
        self.month = month
        self.expenses = inMonth
        self.spentThisMonth = inMonth.reduce(.zero) { $0 + $1.amount }
        // Income arrives with the next slice; until then everything recorded is money spent.
        self.leftToSpend = allExpenses.reduce(.zero) { $0 - $1.amount }
    }
}

public struct GetMonthBudget: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    /// Defaults to the month containing today.
    public func callAsFunction(for month: CalendarDate.YearMonth? = nil) throws -> MonthBudget {
        MonthBudget(allExpenses: try expenses.all(), month: month ?? clock.today().yearMonth)
    }
}
