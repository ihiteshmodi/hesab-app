import Foundation

public struct Expense: Equatable, Sendable {
    public let id: Int64?
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let category: String
    public let subCategory: String?
    public let entity: String?
    /// Who the money was spent for; nil means the owner.
    public let spentFor: String?
    public let tags: [String]
    public let paymentMethod: PaymentMethod
    public let notes: String
    public let refund: RefundState
    /// A cash withdrawal the owner keeps as cash in hand; false for everything else.
    public let keptAsCash: Bool
    /// Set when it was paid in another currency; `amount` is then the home amount.
    public let foreign: ForeignAmount?

    /// What the expense really cost: the amount minus what came back.
    public var netAmount: Money {
        if case .settled(let received) = refund { return amount - received }
        return amount
    }

    /// Checks the rules for an expense; the first broken rule is reported.
    static func validated(_ new: NewExpense, today: CalendarDate, id: Int64? = nil) throws -> Expense {
        let amount: Money
        let foreign: ForeignAmount?
        if let spend = new.foreign {
            let resolved = try spend.resolved()
            (amount, foreign) = (resolved.home, resolved.foreign)
        } else {
            guard let typed = new.amount, typed > .zero else {
                if let typed = new.amount, typed < .zero { throw ExpenseValidationError.amountNegative }
                throw ExpenseValidationError.amountMissingOrZero
            }
            (amount, foreign) = (typed, nil)
        }
        let description = new.description.trimmed
        guard !description.isEmpty else { throw ExpenseValidationError.descriptionMissing }
        guard !new.category.isEmpty else { throw ExpenseValidationError.categoryMissing }
        return Expense(
            id: id, date: new.date ?? today, description: description, amount: amount,
            category: new.category, subCategory: new.subCategory.trimmed.nilIfEmpty,
            entity: new.entity.trimmed.nilIfEmpty, spentFor: new.spentFor.trimmed.nilIfEmpty,
            tags: Self.cleaned(tags: new.tags), paymentMethod: new.paymentMethod,
            notes: new.notes.trimmed, refund: .notRefundable,
            keptAsCash: new.keepAsCash && new.paymentMethod == .cashWithdrawal, foreign: foreign
        )
    }

    /// Trimmed, empty ones dropped, the first spelling kept when two differ only by case.
    private static func cleaned(tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.map(\.trimmed).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

/// What the person typed; `amount` is nil when the field was left empty.
public struct NewExpense: Sendable {
    public var date: CalendarDate?
    public var description: String
    public var amount: Money?
    public var category: String
    public var subCategory: String
    public var entity: String
    public var spentFor: String
    public var tags: [String]
    public var paymentMethod: PaymentMethod
    public var notes: String
    public var keepAsCash: Bool
    /// Set for an expense paid in another currency; `amount` is then ignored.
    public var foreign: ForeignSpend?

    public init(
        date: CalendarDate? = nil, description: String, amount: Money?, category: String,
        subCategory: String = "", entity: String = "", spentFor: String = "", tags: [String] = [],
        paymentMethod: PaymentMethod = .upi, notes: String = "", keepAsCash: Bool = false, foreign: ForeignSpend? = nil
    ) {
        self.foreign = foreign
        self.keepAsCash = keepAsCash
        self.date = date
        self.description = description
        self.amount = amount
        self.category = category
        self.subCategory = subCategory
        self.entity = entity
        self.spentFor = spentFor
        self.tags = tags
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}

public enum ExpenseValidationError: Error, Equatable, Sendable {
    case amountMissingOrZero
    case amountNegative
    case descriptionMissing
    case categoryMissing
    case rateMissing
    case rateNotPositive

    public var message: String {
        switch self {
        case .rateMissing: "Enter the exchange rate"
        case .rateNotPositive: "Enter an exchange rate above 0"
        case .amountMissingOrZero: "Enter an amount above 0"
        case .amountNegative: "Enter an amount above 0. To record money received, add it under Income."
        case .descriptionMissing: "Enter a description"
        case .categoryMissing: "Choose a category"
        }
    }
}

public struct ExpenseNotFound: Error, Equatable, Sendable {
    public let id: Int64
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
