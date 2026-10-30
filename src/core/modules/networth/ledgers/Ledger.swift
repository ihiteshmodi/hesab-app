/// Money held for, or paid out for, one person.
public struct Ledger: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let countsTowardsNetWorth: Bool
}

public struct NewLedger: Sendable {
    public var name: String
    public var countsTowardsNetWorth: Bool

    public init(name: String, countsTowardsNetWorth: Bool = false) {
        self.name = name
        self.countsTowardsNetWorth = countsTowardsNetWorth
    }
}

/// `value` is nil when the field was left empty; negative means money paid out.
public struct NewLedgerEntry: Sendable {
    public var date: CalendarDate?
    public var description: String
    public var value: Money?

    public init(date: CalendarDate? = nil, description: String, value: Money?) {
        self.date = date
        self.description = description
        self.value = value
    }
}

public struct LedgerEntry: Equatable, Sendable {
    public let id: Int64
    public let ledgerID: Int64
    public let date: CalendarDate
    public let description: String
    public let amount: Money
}

/// One line of a ledger: an entry typed in, or an expense paid from it.
public struct LedgerLine: Equatable, Sendable {
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let entryID: Int64?
}

public struct LedgerSummary: Equatable, Sendable {
    public let ledger: Ledger
    public let balance: Money
    /// Newest first.
    public let lines: [LedgerLine]
}

public struct LedgerOverview: Equatable, Sendable {
    public let ledgers: [LedgerSummary]
    public let total: Money
}

public struct LedgerEntryAdded: Equatable, Sendable {
    public let entry: LedgerEntry
    public let warning: String?
}

public enum LedgerError: Error, Equatable, Sendable {
    case nameMissing
    case nameTaken(String)
    case valueMissingOrZero
    case notFound(Int64)
    case hasExpenses(name: String, count: Int)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .nameTaken(let name): "A ledger called \(name) already exists"
        case .valueMissingOrZero: "Enter a value other than 0"
        case .notFound: "That ledger no longer exists."
        case .hasExpenses(let name, let count):
            "\(name) has \(count) expense\(count == 1 ? "" : "s") paid from it. Change their payment method first."
        }
    }
}

enum LedgerBook {
    /// A ledger's balance is its entries minus what was really spent from it; a refund gives money back.
    static func summaries(ledgers: [Ledger], entries: [LedgerEntry], expenses: [Expense]) -> [LedgerSummary] {
        ledgers.map { ledger in
            let typed = entries.filter { $0.ledgerID == ledger.id }.map {
                LedgerLine(date: $0.date, description: $0.description, amount: $0.amount, entryID: $0.id)
            }
            let paid = expenses.filter { Self.isPaidFrom(ledger, $0) }.map {
                LedgerLine(date: $0.date, description: "Paid: \($0.description)", amount: .zero - $0.netAmount, entryID: nil)
            }
            let lines = (typed + paid).sorted { ($0.date, $0.entryID ?? 0) > ($1.date, $1.entryID ?? 0) }
            return LedgerSummary(ledger: ledger, balance: lines.reduce(.zero) { $0 + $1.amount }, lines: lines)
        }
    }

    static func isPaidFrom(_ ledger: Ledger, _ expense: Expense) -> Bool {
        expense.paymentMethod.source == .ledger && expense.paymentMethod.name.lowercased() == ledger.name.lowercased()
    }
}
