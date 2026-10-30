public struct MonthBudget: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    /// What is left in the bank for bank, card and withdrawal spending, across all months.
    public let leftToSpend: Money
    /// Bank-side spending in the viewed month; cash and ledger spending are left out.
    public let spentThisMonth: Money
    public let incomeThisMonth: Money
    /// Every expense of the viewed month, newest first.
    public let expenses: [Expense]
    /// Income entries of the viewed month, newest first.
    public let incomeEntries: [IncomeEntry]
    public let hasNoEntriesAtAll: Bool

    init(allExpenses: [Expense], allIncome: [IncomeEntry], month: CalendarDate.YearMonth) {
        let expensesInMonth = allExpenses
            .filter { $0.date.yearMonth == month }
            .sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
        let incomeInMonth = allIncome
            .filter { $0.date.yearMonth == month }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        let bankSpend: (Expense) -> Money = { $0.paymentMethod.movesLeftToSpend ? $0.amount : .zero }

        self.month = month
        self.expenses = expensesInMonth
        self.incomeEntries = incomeInMonth
        self.spentThisMonth = expensesInMonth.reduce(.zero) { $0 + bankSpend($1) }
        self.incomeThisMonth = incomeInMonth.filter(\.kind.countsAsIncome).reduce(.zero) { $0 + $1.amount }
        let moneyIn = allIncome.filter(\.kind.addsToLeftToSpend).reduce(Money.zero) { $0 + $1.amount }
        let savings = allIncome.filter { !$0.kind.addsToLeftToSpend }.reduce(Money.zero) { $0 + $1.amount }
        self.leftToSpend = moneyIn - savings - allExpenses.reduce(.zero) { $0 + bankSpend($1) }
        self.hasNoEntriesAtAll = allExpenses.isEmpty && allIncome.isEmpty
    }
}

public struct GetMonthBudget: Sendable {
    let expenses: ExpenseRepository
    let income: IncomeRepository
    let clock: any DayClock

    /// Defaults to the month containing today.
    public func callAsFunction(for month: CalendarDate.YearMonth? = nil) throws -> MonthBudget {
        MonthBudget(
            allExpenses: try expenses.all(), allIncome: try income.all(),
            month: month ?? clock.today().yearMonth
        )
    }
}
