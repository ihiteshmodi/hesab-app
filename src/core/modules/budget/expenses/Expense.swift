import Foundation

public struct Expense: Equatable, Sendable {
    public let id: Int64?
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let category: String

    /// Checks the rules for a new expense; the first broken rule is reported.
    static func validated(_ new: NewExpense, today: CalendarDate) throws -> Expense {
        guard let amount = new.amount, amount > .zero else {
            if let amount = new.amount, amount < .zero { throw ExpenseValidationError.amountNegative }
            throw ExpenseValidationError.amountMissingOrZero
        }
        let description = new.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw ExpenseValidationError.descriptionMissing }
        guard !new.category.isEmpty else { throw ExpenseValidationError.categoryMissing }
        return Expense(id: nil, date: new.date ?? today, description: description, amount: amount, category: new.category)
    }
}

/// What the person typed; `amount` is nil when the field was left empty.
public struct NewExpense: Sendable {
    public var date: CalendarDate?
    public var description: String
    public var amount: Money?
    public var category: String

    public init(date: CalendarDate? = nil, description: String, amount: Money?, category: String) {
        self.date = date
        self.description = description
        self.amount = amount
        self.category = category
    }
}

public enum ExpenseValidationError: Error, Equatable, Sendable {
    case amountMissingOrZero
    case amountNegative
    case descriptionMissing
    case categoryMissing

    public var message: String {
        switch self {
        case .amountMissingOrZero: "Enter an amount above 0"
        case .amountNegative: "Enter an amount above 0. To record money received, add it under Income."
        case .descriptionMissing: "Enter a description"
        case .categoryMissing: "Choose a category"
        }
    }
}
