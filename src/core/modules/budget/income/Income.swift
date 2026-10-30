public enum IncomeKind: String, CaseIterable, Sendable {
    case salary
    case savings
    case investmentIncome = "investment_income"
    case moneyReceived = "money_received"
    case borrowed

    /// Money that goes up "left to spend"; savings is the one kind that takes it down.
    var addsToLeftToSpend: Bool { self != .savings }
    /// Borrowed money and money moved to savings are not income.
    var countsAsIncome: Bool { self == .salary || self == .investmentIncome || self == .moneyReceived }
}

public struct IncomeEntry: Equatable, Sendable {
    public let id: Int64
    public let date: CalendarDate
    public let kind: IncomeKind
    public let amount: Money
    public let note: String
}

/// What the person typed; `kind` and `amount` are nil when left empty.
public struct NewIncome: Sendable {
    public var date: CalendarDate?
    public var kind: IncomeKind?
    public var amount: Money?
    public var note: String

    public init(date: CalendarDate? = nil, kind: IncomeKind?, amount: Money?, note: String = "") {
        self.date = date
        self.kind = kind
        self.amount = amount
        self.note = note
    }
}

public enum IncomeValidationError: Error, Equatable, Sendable {
    case amountMissingOrZero
    case typeMissing

    public var message: String {
        switch self {
        case .amountMissingOrZero: "Enter an amount above 0"
        case .typeMissing: "Choose a type"
        }
    }
}

public struct IncomeNotFound: Error, Equatable, Sendable {
    public let id: Int64
}
