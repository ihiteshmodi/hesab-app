public struct GetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository
    let trips: TripRepository

    public func callAsFunction() throws -> CashInHand {
        CashInHand(expenses: try expenses.all(), adjustments: try adjustments.all() + trips.homeCashMovements())
    }
}

public struct SetCashInHand: Sendable {
    let expenses: ExpenseRepository
    let adjustments: CashAdjustmentRepository
    let trips: TripRepository
    let clock: any DayClock

    /// Records the difference as an adjustment, so the history still adds up.
    public func callAsFunction(to target: Money) throws {
        let current = CashInHand(
            expenses: try expenses.all(), adjustments: try adjustments.all() + trips.homeCashMovements()
        ).balance
        guard target != current else { return }
        try adjustments.add(date: clock.today(), amount: target - current, note: "Adjustment")
    }
}
