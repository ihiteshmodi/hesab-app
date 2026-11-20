public enum BreakdownPeriod: Equatable, Sendable {
    case month(CalendarDate.YearMonth)
    case allTime
}

public enum BreakdownGrouping: String, CaseIterable, Equatable, Sendable {
    case category, paymentMethod, entity, spentFor, subCategory, tag

    public var title: String {
        switch self {
        case .category: "Category"
        case .paymentMethod: "Payment"
        case .entity: "Entity"
        case .spentFor: "Spent for"
        case .subCategory: "Sub-category"
        case .tag: "Tag"
        }
    }

    /// The names an expense is counted under; only tags can give more than one.
    func names(_ expense: Expense) -> [String] {
        switch self {
        case .category: [expense.category]
        case .paymentMethod: [expense.paymentMethod.name]
        case .entity: [expense.entity ?? "No entity"]
        case .spentFor: [expense.spentFor ?? "Me"]
        case .subCategory: [expense.subCategory.map { "\($0) (\(expense.category))" } ?? "\(expense.category) (no sub-category)"]
        case .tag: expense.tags.isEmpty ? ["No tag"] : expense.tags
        }
    }
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
        self.init(expenses: expenses) { [name($0)] }
    }

    /// An expense under several names counts in each row but once in the total.
    init(expenses: [Expense], names: (Expense) -> [String]) {
        var totals: [String: Money] = [:]
        for expense in expenses {
            for name in Set(names(expense)) { totals[name, default: .zero] = totals[name, default: .zero] + expense.netAmount }
        }
        let total = expenses.reduce(Money.zero) { $0 + $1.netAmount }
        self.total = total
        self.expenses = expenses.sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
        rows = totals.map { name, amount in
            // Half-up rounding in whole paise; a zero total cannot have rows with money.
            let share = total == .zero ? 0 : (amount.paise * 100 + total.paise / 2) / total.paise
            return BreakdownRow(name: name, amount: amount, sharePercent: share)
        }
        .sorted { ($1.amount, $0.name) < ($0.amount, $1.name) }
    }

    /// The largest rows that together reach `percent` of the total; whatever is left is `rest`.
    public func top(percent: Int) -> (rows: [BreakdownRow], rest: Money) {
        let kept = Self.prefix(rows, reaching: percent, of: total, amount: \.amount)
        return (kept, total - kept.reduce(.zero) { $0 + $1.amount })
    }

    /// The largest expenses that together reach `percent` of the total, largest first.
    public func topExpenses(percent: Int) -> [Expense] {
        Self.prefix(expenses.sorted { $0.netAmount > $1.netAmount }, reaching: percent, of: total, amount: \.netAmount)
    }

    /// The expenses kept by `topExpenses(percent:)`, put in the order she chose.
    public func topExpenses(percent: Int, sortedBy sort: ExpenseSort) -> [Expense] {
        topExpenses(percent: percent).sorted(by: sort.areInIncreasingOrder)
    }

    /// What the rows kept by `top(percent:)` add up to; this is the "Total spent" to show while the slider is below 100.
    public func shownTotal(percent: Int) -> Money {
        total - top(percent: percent).rest
    }

    /// What the expenses kept by `topExpenses(percent:)` add up to.
    public func shownExpensesTotal(percent: Int) -> Money {
        topExpenses(percent: percent).reduce(.zero) { $0 + $1.netAmount }
    }

    private static func prefix<T>(_ items: [T], reaching percent: Int, of total: Money, amount: (T) -> Money) -> [T] {
        guard percent < 100 else { return items }
        var kept: [T] = []
        var sum = Money.zero
        for item in items where sum.paise * 100 < total.paise * percent {
            kept.append(item)
            sum = sum + amount(item)
        }
        return kept
    }
}

/// How the expenses inside an opened report row are ordered.
public enum ExpenseSort: String, CaseIterable, Sendable {
    case newestFirst, oldestFirst, highestFirst, lowestFirst

    public var title: String {
        switch self {
        case .newestFirst: "Newest first"
        case .oldestFirst: "Oldest first"
        case .highestFirst: "Highest first"
        case .lowestFirst: "Lowest first"
        }
    }

    /// By date or by what the expense really cost; ties fall back to the newest, so the list never shuffles.
    func areInIncreasingOrder(_ a: Expense, _ b: Expense) -> Bool {
        let newer = (a.date, a.id ?? 0) > (b.date, b.id ?? 0)
        switch self {
        case .newestFirst: return newer
        case .oldestFirst: return (a.date, a.id ?? 0) < (b.date, b.id ?? 0)
        case .highestFirst: return a.netAmount != b.netAmount ? a.netAmount > b.netAmount : newer
        case .lowestFirst: return a.netAmount != b.netAmount ? a.netAmount < b.netAmount : newer
        }
    }
}

public struct GetSpendingBreakdown: Sendable {
    let expenses: ExpenseRepository

    public func callAsFunction(_ period: BreakdownPeriod, by grouping: BreakdownGrouping) throws -> Breakdown {
        let inPeriod = try expenses.all().filter { Self.contains($0, period) }
        return Breakdown(expenses: inPeriod, names: grouping.names)
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

public struct GetGroupBreakdown: Sendable {
    let expenses: ExpenseRepository

    /// The expenses behind one row of a report, split by sub-category for a category and by category otherwise.
    /// `only` keeps just the expenses under those split rows; empty keeps everything.
    public func callAsFunction(
        _ grouping: BreakdownGrouping, _ name: String, _ period: BreakdownPeriod, only: Set<String> = []
    ) throws -> Breakdown {
        let split: (Expense) -> String = grouping == .category ? { $0.subCategory ?? "No sub-category" } : { $0.category }
        let mine = try expenses.all().filter {
            GetSpendingBreakdown.contains($0, period) && grouping.names($0).contains(name) && (only.isEmpty || only.contains(split($0)))
        }
        return Breakdown(expenses: mine, name: split)
    }
}
