public struct CashLine: Equatable, Sendable {
    public enum Kind: Sendable { case withdrawalKept, adjustment, borrowed, repaid, expense }

    public let kind: Kind
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let runningBalance: Money
    /// Set for cash added by hand, the only lines changed or deleted from the cash list.
    public let adjustmentID: Int64?
}

public struct CashInHand: Equatable, Sendable {
    public let balance: Money
    public let warning: String?
    /// Oldest first, each with the balance after it.
    public let lines: [CashLine]

    init(
        expenses: [Expense], adjustments: [CashAdjustment], borrowings: [IncomeEntry] = [], repayments: [Repayment] = []
    ) {
        struct Movement {
            let kind: CashLine.Kind; let date: CalendarDate; let description: String; let amount: Money; let id: Int64
            var adjustmentID: Int64? = nil
        }
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
            Movement(kind: .adjustment, date: $0.date, description: $0.note, amount: $0.amount, id: $0.id, adjustmentID: $0.editable ? $0.id : nil)
        }
        let cashLoans = borrowings.filter { $0.kind == .borrowed && $0.viaCash }
        movements += cashLoans.map {
            Movement(kind: .borrowed, date: $0.date, description: "Borrowed from \($0.note)", amount: $0.amount, id: $0.id)
        }
        movements += repayments.filter(\.fromCash).map { repayment in
            let lender = borrowings.first { $0.id == repayment.borrowingID }?.note ?? ""
            return Movement(kind: .repaid, date: repayment.date, description: "Repaid \(lender)", amount: .zero - repayment.amount, id: repayment.id)
        }
        let rank: (CashLine.Kind) -> Int = {
            switch $0 {
            case .withdrawalKept: 0
            case .adjustment, .borrowed: 1
            case .repaid, .expense: 2
            }
        }
        movements.sort { ($0.date, rank($0.kind), $0.id) < ($1.date, rank($1.kind), $1.id) }

        var running = Money.zero
        lines = movements.map {
            running = running + $0.amount
            return CashLine(
                kind: $0.kind, date: $0.date, description: $0.description, amount: $0.amount, runningBalance: running,
                adjustmentID: $0.adjustmentID
            )
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
    /// Cash typed in by hand; trip leftovers are changed from their trip.
    public let editable: Bool

    public init(id: Int64, date: CalendarDate, amount: Money, note: String, editable: Bool = false) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
        self.editable = editable
    }
}
