public struct MarkRefundable: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        try expenses.change(id) { try $0.markedRefundable() }
    }
}

public struct RecordReceived: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64, _ received: Money) throws {
        try expenses.change(id) { try $0.receiving(received) }
    }
}

public struct UndoSettlement: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        try expenses.change(id) { $0.settlementUndone() }
    }
}

public struct UnmarkRefundable: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        try expenses.change(id) { try $0.unmarked() }
    }
}

public struct PendingRefunds: Equatable, Sendable {
    /// Oldest first.
    public let expenses: [Expense]
    public let stillToCome: Money

    init(allExpenses: [Expense]) {
        expenses = allExpenses
            .filter { $0.refund == .pending }
            .sorted { ($0.date, $0.id ?? 0) < ($1.date, $1.id ?? 0) }
        stillToCome = expenses.reduce(.zero) { $0 + $1.amount }
    }
}

public struct GetPendingRefunds: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction() throws -> PendingRefunds {
        PendingRefunds(allExpenses: try expenses.all())
    }
}
