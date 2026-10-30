public struct SearchMonth: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    /// Newest first.
    public let expenses: [Expense]
}

public struct SearchResults: Equatable, Sendable {
    /// Newest month first.
    public let groups: [SearchMonth]
    /// What the matching expenses really cost, after refunds.
    public let total: Money

    public init(groups: [SearchMonth], total: Money) {
        self.groups = groups
        self.total = total
    }
}

public struct SearchExpenses: Sendable {
    let expenses: ExpenseRepository

    /// Matches the description, entity, category, notes or amount, ignoring case.
    public func callAsFunction(_ typed: String) throws -> SearchResults {
        let text = typed.trimmed.lowercased()
        guard !text.isEmpty else { return SearchResults(groups: [], total: .zero) }
        let amountText = text.filter { $0 != "," && $0 != "₹" && !$0.isWhitespace }
        let matching = try expenses.all().filter { expense in
            let words = [expense.description, expense.entity ?? "", expense.category, expense.subCategory ?? "", expense.notes]
            return words.contains { $0.lowercased().contains(text) }
                || (amountText.allSatisfy { $0.isNumber || $0 == "." } && Self.digits(expense.amount).contains(amountText))
        }
        let groups = Dictionary(grouping: matching, by: { $0.date.yearMonth }).map { month, items in
            SearchMonth(month: month, expenses: items.sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) })
        }
        return SearchResults(
            groups: groups.sorted { $0.month > $1.month }, total: matching.reduce(.zero) { $0 + $1.netAmount }
        )
    }

    /// "1250" or "1250.50": the amount as typed without grouping.
    private static func digits(_ money: Money) -> String {
        let paise = money.paise % 100
        return paise == 0 ? String(money.paise / 100) : "\(money.paise / 100).\(paise < 10 ? "0" : "")\(paise)"
    }
}
