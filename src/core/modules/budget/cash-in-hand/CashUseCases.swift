public struct GetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository
    let trips: TripRepository
    let income: IncomeRepository
    let repayments: BorrowingRepository

    public func callAsFunction() throws -> CashInHand {
        CashInHand(
            expenses: try expenses.all(), adjustments: try adjustments.all() + trips.homeCashMovements(),
            borrowings: try income.all(), repayments: try repayments.all()
        )
    }
}

public enum CashError: Error, Equatable, Sendable {
    case amountMissingOrZero

    public var message: String { "Enter an amount above 0" }
}

/// Cash that came in some other way, with a title for the list.
public struct AddCash: Sendable {
    let adjustments: CashAdjustmentRepository
    let clock: any DayClock

    public func callAsFunction(_ amount: Money?, note: String, on date: CalendarDate? = nil) throws {
        guard let amount, amount > .zero else { throw CashError.amountMissingOrZero }
        let title = note.trimmed
        try adjustments.add(date: date ?? clock.today(), amount: amount, note: title.isEmpty ? "Cash added" : title)
    }
}

public struct SetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository
    let trips: TripRepository
    let income: IncomeRepository
    let repayments: BorrowingRepository
    let clock: any DayClock

    /// Records the difference as an adjustment, so the history still adds up.
    public func callAsFunction(to target: Money) throws {
        let current = CashInHand(
            expenses: try expenses.all(), adjustments: try adjustments.all() + trips.homeCashMovements(),
            borrowings: try income.all(), repayments: try repayments.all()
        ).balance
        guard target != current else { return }
        try adjustments.add(date: clock.today(), amount: target - current, note: "Adjustment")
    }
}
