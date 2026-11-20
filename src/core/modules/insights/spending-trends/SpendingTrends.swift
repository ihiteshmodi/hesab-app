// Spending trends for Reports. "Spent" is the same as everywhere else on Reports: every expense after refunds.

extension IncomeKind {
    /// What counts as income in "Income this month" and in the trends; a move into savings never does.
    func countsAsIncome(_ preferences: Preferences) -> Bool {
        switch self {
        case .salary, .investmentIncome: true
        case .moneyReceived: preferences.countMoneyReceivedAsIncome
        case .borrowed: preferences.countBorrowedAsIncome
        case .savings: false
        }
    }
}

private extension Sequence where Element == Expense {
    func spent(in month: CalendarDate.YearMonth, throughDay lastDay: Int = 31) -> Money {
        filter { $0.date.yearMonth == month && $0.date.day <= lastDay }.reduce(.zero) { $0 + $1.netAmount }
    }
}

// MARK: this month against last month

public struct SpendingPace: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    /// How many days of the month are counted: up to today for this month, the whole month for an earlier one.
    public let upToDay: Int
    /// Running total for day 1 to `upToDay`.
    public let thisMonth: [Money]
    /// Running total for every day of the month before.
    public let lastMonth: [Money]

    /// Last month's running total on the same day, or on its last day when it was shorter.
    public var lastMonthAtSameDay: Money {
        guard upToDay > 0, !lastMonth.isEmpty else { return .zero }
        return lastMonth[min(upToDay, lastMonth.count) - 1]
    }

    public var difference: Money { (thisMonth.last ?? .zero) - lastMonthAtSameDay }
}

public struct GetSpendingPace: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    public func callAsFunction(for month: CalendarDate.YearMonth? = nil) throws -> SpendingPace {
        let today = clock.today()
        let month = month ?? today.yearMonth
        let upToDay = month < today.yearMonth ? month.dayCount : month == today.yearMonth ? today.day : 0
        let all = try expenses.all()
        let previous = month.shifted(by: -1)
        return SpendingPace(
            month: month, upToDay: upToDay, thisMonth: Self.running(all, month, days: upToDay),
            lastMonth: Self.running(all, previous, days: previous.dayCount)
        )
    }

    private static func running(_ expenses: [Expense], _ month: CalendarDate.YearMonth, days: Int) -> [Money] {
        let perDay = Dictionary(grouping: expenses.filter { $0.date.yearMonth == month }, by: \.date.day)
            .mapValues { $0.reduce(Money.zero) { $0 + $1.netAmount } }
        var total = Money.zero
        return (0..<days).map { index in
            total = total + (perDay[index + 1] ?? .zero)
            return total
        }
    }
}

// MARK: income against spent

public struct MonthTrend: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    public let income: Money
    public let spent: Money
    /// The share of income kept, in whole percent; nil while the month is running or when there was no income.
    public let savingsRatePercent: Int?
    public let isInProgress: Bool
}

public struct GetMonthlyTrend: Sendable {
    let expenses: ExpenseRepository
    let income: IncomeRepository
    let settings: SettingsRepository
    let clock: any DayClock

    /// Oldest first, ending at `endingAt` (default: this month).
    public func callAsFunction(endingAt end: CalendarDate.YearMonth? = nil, months count: Int = 6) throws -> [MonthTrend] {
        let today = clock.today()
        let end = end ?? today.yearMonth
        let preferences = Preferences(stored: try settings.all())
        let allExpenses = try expenses.all()
        let allIncome = try income.all().filter { $0.kind.countsAsIncome(preferences) }
        return (0..<count).map { offset in
            let month = end.shifted(by: offset - count + 1)
            let earned = allIncome.filter { $0.date.yearMonth == month }.reduce(Money.zero) { $0 + $1.amount }
            let spent = allExpenses.spent(in: month)
            let running = month >= today.yearMonth
            // Half-up rounding in whole paise, like the report shares.
            let rate = running || earned <= .zero ? nil : ((earned - spent).paise * 100 + (earned - spent).paise.signum() * earned.paise / 2) / earned.paise
            return MonthTrend(month: month, income: earned, spent: spent, savingsRatePercent: rate, isInProgress: running)
        }
    }
}

// MARK: against normal

public struct CategoryChange: Equatable, Sendable {
    public let category: String
    /// So far this month (to today, or the whole month once it is over).
    public let thisMonth: Money
    /// The average of the same days in the 3 months before.
    public let usual: Money

    public var difference: Money { thisMonth - usual }
}

public struct SpendingVsNormal: Equatable, Sendable {
    /// The biggest moves first, at most six.
    public let changes: [CategoryChange]
    /// Needs her first expense to be at least 3 months before the month shown.
    public let hasHistory: Bool

    public init(changes: [CategoryChange], hasHistory: Bool) {
        self.changes = changes
        self.hasHistory = hasHistory
    }
}

/// Every category's spending this month against the average of the same days in the 3 months before.
struct NormalSpending {
    let all: [CategoryChange]
    let hasHistory: Bool

    init(_ expenses: [Expense], month: CalendarDate.YearMonth, today: CalendarDate) {
        let throughDay = month < today.yearMonth ? month.dayCount : month == today.yearMonth ? today.day : 0
        let earlier = (1...3).map { month.shifted(by: -$0) }
        hasHistory = expenses.map(\.date.yearMonth).min().map { $0 <= month.shifted(by: -3) } ?? false
        let categories = Set(expenses.filter { $0.date.yearMonth == month || earlier.contains($0.date.yearMonth) }.map(\.category))
        all = categories.map { category in
            let mine = expenses.filter { $0.category == category }
            let usualPaise = earlier.reduce(0) { $0 + mine.spent(in: $1, throughDay: throughDay).paise } / 3
            return CategoryChange(
                category: category, thisMonth: mine.spent(in: month, throughDay: throughDay), usual: Money(paise: usualPaise)
            )
        }
    }
}

public struct GetSpendingVsNormal: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    /// Moves smaller than ₹100 either way are not worth a line.
    public func callAsFunction(for month: CalendarDate.YearMonth? = nil, limit: Int = 6) throws -> SpendingVsNormal {
        let today = clock.today()
        let normal = NormalSpending(try expenses.all(), month: month ?? today.yearMonth, today: today)
        guard normal.hasHistory else { return SpendingVsNormal(changes: [], hasHistory: false) }
        let moved = normal.all
            .filter { $0.difference != .zero && max($0.thisMonth.paise, $0.usual.paise) >= 10_000 }
            .sorted { (abs($1.difference.paise), $0.category) < (abs($0.difference.paise), $1.category) }
        return SpendingVsNormal(changes: Array(moved.prefix(limit)), hasHistory: true)
    }
}

// MARK: six months on each category

public struct CategoryTrend: Equatable, Sendable {
    public let category: String
    /// Oldest first, ending at the month shown.
    public let values: [Money]
    /// This month is 25% or more above her usual for the same days; a category with no earlier spending is never rising.
    public let isRising: Bool
}

public struct GetCategoryTrends: Sendable {
    let expenses: ExpenseRepository
    let clock: any DayClock

    /// Biggest total first.
    public func callAsFunction(endingAt end: CalendarDate.YearMonth? = nil, months count: Int = 6) throws -> [CategoryTrend] {
        let today = clock.today()
        let end = end ?? today.yearMonth
        let all = try expenses.all()
        let span = (0..<count).map { end.shifted(by: $0 - count + 1) }
        let usual = Dictionary(uniqueKeysWithValues: NormalSpending(all, month: end, today: today).all.map { ($0.category, $0) })
        let categories = Set(all.filter { span.contains($0.date.yearMonth) }.map(\.category))
        return categories.map { category in
            let mine = all.filter { $0.category == category }
            let change = usual[category]
            let rising = change.map { $0.usual > .zero && $0.thisMonth.paise * 4 >= $0.usual.paise * 5 } ?? false
            return CategoryTrend(category: category, values: span.map { mine.spent(in: $0) }, isRising: rising)
        }
        .sorted { ($1.values.reduce(0) { $0 + $1.paise }, $0.category) < ($0.values.reduce(0) { $0 + $1.paise }, $1.category) }
    }
}
