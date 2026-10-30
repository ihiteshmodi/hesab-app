public struct GetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository

    public func callAsFunction() throws -> CashInHand {
        CashInHand(expenses: try expenses.all(), adjustments: try adjustments.all())
    }
}

public struct SetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository
    let clock: any DayClock

    /// Records the difference as an adjustment, so the history still adds up.
    public func callAsFunction(to target: Money) throws {
        let current = CashInHand(expenses: try expenses.all(), adjustments: try adjustments.all()).balance
        guard target != current else { return }
        try adjustments.add(date: clock.today(), amount: target - current, note: "Adjustment")
    }
}
