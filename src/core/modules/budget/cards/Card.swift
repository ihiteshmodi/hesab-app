public struct Card: Hashable, Sendable {
    public let id: Int64
    public let name: String
}

public struct NewCard: Sendable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public enum CardError: Error, Equatable, Sendable {
    case nameMissing
    case nameTaken(String)
    case notFound(Int64)
    case nothingToPay(card: String, month: String)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .nameTaken(let name): "A card called \(name) already exists"
        case .notFound: "That card no longer exists."
        case .nothingToPay(let card, let month): "Nothing to pay for \(card) in \(month)."
        }
    }
}

/// One card's bill for one month; paying never moves "left to spend", the money was counted when spent.
public struct CardBillLine: Equatable, Sendable {
    public let card: Card
    /// The sum of what each expense on the card really cost that month.
    public let bill: Money
    /// What was ticked as paid; charges added afterwards are not part of it.
    public let paid: Money

    public var due: Money { max(bill - paid, .zero) }
    public var isPaid: Bool { paid > .zero }
}

public struct CardBills: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    public let lines: [CardBillLine]

    public var totalDue: Money { lines.reduce(.zero) { $0 + $1.due } }
    public var hasCardSpending: Bool { lines.contains { $0.bill != .zero } }

    init(month: CalendarDate.YearMonth, cards: [Card], expenses: [Expense], paid: [Int64: Money]) {
        self.month = month
        lines = cards.map { card in
            let bill = expenses
                .filter { $0.date.yearMonth == month && $0.paymentMethod == .bank(card.name) }
                .reduce(Money.zero) { $0 + $1.netAmount }
            return CardBillLine(card: card, bill: bill, paid: paid[card.id] ?? .zero)
        }
    }
}
