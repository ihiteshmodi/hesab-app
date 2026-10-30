public enum BreakdownPeriod: Equatable, Sendable {
    case month(CalendarDate.YearMonth)
    case allTime
}

public enum BreakdownGrouping: Equatable, Sendable {
    case category, paymentMethod, entity
}

public struct BreakdownRow: Equatable, Sendable {
    public let name: String
    public let amount: Money
    public let sharePercent: Int
}

public struct Breakdown: Equatable, Sendable {
    /// Largest first.
    public let rows: [BreakdownRow]
    public let total: Money
    /// The expenses behind the rows, newest first.
    public let expenses: [Expense]

    public var isEmpty: Bool { rows.isEmpty }

    public static let empty = Breakdown(expenses: []) { $0.category }

    init(expenses: [Expense], name: (Expense) -> String) {
        let totals = Dictionary(grouping: expenses, by: name).mapValues { $0.reduce(Money.zero) { $0 + $1.netAmount } }
        let total = totals.values.reduce(.zero, +)
        self.total = total
        self.expenses = expenses.sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
        rows = totals.map { name, amount in
            // Half-up rounding in whole paise; a zero total cannot have rows with money.
            let share = total == .zero ? 0 : (amount.paise * 100 + total.paise / 2) / total.paise
            return BreakdownRow(name: name, amount: amount, sharePercent: share)
        }
        .sorted { ($1.amount, $0.name) < ($0.amount, $1.name) }
    }
}

public struct GetSpendingBreakdown: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ period: BreakdownPeriod, by grouping: BreakdownGrouping) throws -> Breakdown {
        let inPeriod = try expenses.all().filter { Self.contains($0, period) }
        switch grouping {
        case .category: return Breakdown(expenses: inPeriod) { $0.category }
        case .paymentMethod: return Breakdown(expenses: inPeriod) { $0.paymentMethod.name }
        case .entity: return Breakdown(expenses: inPeriod) { $0.entity ?? "No entity" }
        }
    }

    static func contains(_ expense: Expense, _ period: BreakdownPeriod) -> Bool {
        switch period {
        case .allTime: true
        case .month(let month): expense.date.yearMonth == month
        }
    }
}

public struct GetCategoryBreakdown: Sendable {
    let expenses: ExpenseRepository

    /// One category's sub-categories; spending with no sub-category is its own row.
    public func callAsFunction(_ category: String, _ period: BreakdownPeriod) throws -> Breakdown {
        let mine = try expenses.all().filter { $0.category == category && GetSpendingBreakdown.contains($0, period) }
        return Breakdown(expenses: mine) { $0.subCategory ?? "No sub-category" }
    }
}
