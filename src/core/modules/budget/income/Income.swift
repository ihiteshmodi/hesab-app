public enum IncomeKind: String, CaseIterable, Sendable {
    case salary
    case savings
    case investmentIncome = "investment_income"
    case moneyReceived = "money_received"
    case borrowed

    /// Money that goes up "left to spend"; savings is the one kind that takes it down.
    var addsToLeftToSpend: Bool { self != .savings }

    public var title: String {
        switch self {
        case .salary: "Salary"
        case .savings: "Savings"
        case .investmentIncome: "Investment Income"
        case .moneyReceived: "Money Received"
        case .borrowed: "Borrowed"
        }
    }
}

public struct IncomeEntry: Equatable, Sendable {
    public let id: Int64
    public let date: CalendarDate
    public let kind: IncomeKind
    public let amount: Money
    public let note: String
    /// Only for borrowed money: it arrived as cash rather than in the bank.
    public let viaCash: Bool

    public init(id: Int64, date: CalendarDate, kind: IncomeKind, amount: Money, note: String, viaCash: Bool = false) {
        self.id = id
        self.date = date
        self.kind = kind
        self.amount = amount
        self.note = note
        self.viaCash = viaCash
    }
}

/// What the person typed; `kind` and `amount` are nil when left empty.
public struct NewIncome: Sendable {
    public var date: CalendarDate?
    public var kind: IncomeKind?
    public var amount: Money?
    public var note: String
    public var viaCash: Bool

    public init(date: CalendarDate? = nil, kind: IncomeKind?, amount: Money?, note: String = "", viaCash: Bool = false) {
        self.date = date
        self.kind = kind
        self.amount = amount
        self.note = note
        self.viaCash = viaCash
    }
}

public enum IncomeValidationError: Error, Equatable, Sendable {
    case amountMissingOrZero
    case typeMissing
    case lenderMissing

    public var message: String {
        switch self {
        case .amountMissingOrZero: "Enter an amount above 0"
        case .typeMissing: "Choose a type"
        case .lenderMissing: "Enter who you borrowed from"
        }
    }
}

public struct IncomeNotFound: Error, Equatable, Sendable {
    public let id: Int64
}
