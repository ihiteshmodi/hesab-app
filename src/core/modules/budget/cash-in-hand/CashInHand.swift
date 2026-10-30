public struct CashLine: Equatable, Sendable {
    public enum Kind: Sendable { case withdrawalKept, adjustment, expense }

    public let kind: Kind
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let runningBalance: Money
}

public struct CashInHand: Equatable, Sendable {
    public let balance: Money
    public let warning: String?
    /// Oldest first, each with the balance after it.
    public let lines: [CashLine]

    init(expenses: [Expense], adjustments: [CashAdjustment]) {
        struct Movement { let kind: CashLine.Kind; let date: CalendarDate; let description: String; let amount: Money; let id: Int64 }
        var movements: [Movement] = expenses.compactMap { expense in
            if expense.keptAsCash {
                return Movement(kind: .withdrawalKept, date: expense.date, description: expense.description, amount: expense.amount, id: expense.id ?? 0)
            }
            if expense.paymentMethod.source == .cash {
                return Movement(kind: .expense, date: expense.date, description: expense.description, amount: .zero - expense.amount, id: expense.id ?? 0)
            }
            return nil
        }
        movements += adjustments.map {
            Movement(kind: .adjustment, date: $0.date, description: $0.note, amount: $0.amount, id: $0.id)
        }
        let rank: (CashLine.Kind) -> Int = { $0 == .withdrawalKept ? 0 : $0 == .adjustment ? 1 : 2 }
        movements.sort { ($0.date, rank($0.kind), $0.id) < ($1.date, rank($1.kind), $1.id) }

        var running = Money.zero
        lines = movements.map {
            running = running + $0.amount
            return CashLine(kind: $0.kind, date: $0.date, description: $0.description, amount: $0.amount, runningBalance: running)
        }
        balance = running
        warning = running < .zero
            ? "You have spent \(IndianMoneyFormat.plain(.zero - running)) more cash than you have recorded."
            : nil
    }
}

public struct CashAdjustment: Equatable, Sendable {
    public let id: Int64
    public let date: CalendarDate
    public let amount: Money
    public let note: String
}
