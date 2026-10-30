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
    public let refundsThisMonth: RefundSummary
    /// Pending refunds from every month, so an old one never drops out of sight.
    public let pendingRefundsEverywhere: PendingRefundTotal

    init(allExpenses: [Expense], allIncome: [IncomeEntry], month: CalendarDate.YearMonth) {
        let expensesInMonth = allExpenses
            .filter { $0.date.yearMonth == month }
            .sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
        let incomeInMonth = allIncome
            .filter { $0.date.yearMonth == month }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        let bankSpend: (Expense) -> Money = { $0.paymentMethod.movesLeftToSpend ? $0.netAmount : .zero }

        self.month = month
        self.expenses = expensesInMonth
        self.incomeEntries = incomeInMonth
        self.spentThisMonth = expensesInMonth.reduce(.zero) { $0 + bankSpend($1) }
        self.incomeThisMonth = incomeInMonth.filter(\.kind.countsAsIncome).reduce(.zero) { $0 + $1.amount }
        let moneyIn = allIncome.filter(\.kind.addsToLeftToSpend).reduce(Money.zero) { $0 + $1.amount }
        let savings = allIncome.filter { !$0.kind.addsToLeftToSpend }.reduce(Money.zero) { $0 + $1.amount }
        self.leftToSpend = moneyIn - savings - allExpenses.reduce(.zero) { $0 + bankSpend($1) }
        self.hasNoEntriesAtAll = allExpenses.isEmpty && allIncome.isEmpty
        self.refundsThisMonth = RefundSummary(expenses: expensesInMonth)
        let pending = PendingRefunds(allExpenses: allExpenses)
        self.pendingRefundsEverywhere = PendingRefundTotal(count: pending.expenses.count, stillToCome: pending.stillToCome)
    }
}

public struct RefundSummary: Equatable, Sendable {
    public let pendingCount: Int
    public let pendingStillToCome: Money
    public let settledCount: Int
    public let receivedTotal: Money

    init(pendingCount: Int, pendingStillToCome: Money, settledCount: Int, receivedTotal: Money) {
        self.pendingCount = pendingCount
        self.pendingStillToCome = pendingStillToCome
        self.settledCount = settledCount
        self.receivedTotal = receivedTotal
    }

    init(expenses: [Expense]) {
        var pending = (count: 0, amount: Money.zero)
        var settled = (count: 0, received: Money.zero)
        for expense in expenses {
            switch expense.refund {
            case .notRefundable: break
            case .pending: pending = (pending.count + 1, pending.amount + expense.amount)
            case .settled(let received): settled = (settled.count + 1, settled.received + received)
            }
        }
        self.init(
            pendingCount: pending.count, pendingStillToCome: pending.amount,
            settledCount: settled.count, receivedTotal: settled.received
        )
    }
}

public struct PendingRefundTotal: Equatable, Sendable {
    public let count: Int
    public let stillToCome: Money
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
