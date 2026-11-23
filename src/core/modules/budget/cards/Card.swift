public struct Card: Hashable, Sendable {
    public let id: Int64
    public let name: String
    /// Nil means the last day of each calendar month; 1...31 sets the monthly cutoff/due day (clamped in short months).
    public let dueDay: Int?

    public init(id: Int64, name: String, dueDay: Int? = nil) {
        self.id = id
        self.name = name
        self.dueDay = dueDay
    }
}

public struct NewCard: Sendable {
    public var name: String
    public var dueDay: Int?

    public init(name: String, dueDay: Int? = nil) {
        self.name = name
        self.dueDay = dueDay
    }
}

public struct CardPayment: Equatable, Sendable {
    public let cardID: Int64
    public let month: CalendarDate.YearMonth
    public let paid: Money
    public let paidUpTo: CalendarDate?
}

public enum CardError: Error, Equatable, Sendable {
    case nameMissing
    case nameTaken(String)
    case invalidDueDay
    case notFound(Int64)
    case nothingToPay(card: String, month: String)
    case cutoffOutOfRange(min: CalendarDate, max: CalendarDate)
    case hasExpenses(name: String, count: Int)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .nameTaken(let name): "A card called \(name) already exists"
        case .invalidDueDay: "Enter a due day between 1 and 31."
        case .notFound: "That card no longer exists."
        case .nothingToPay(let card, let month): "Nothing to pay for \(card) in \(month)."
        case .cutoffOutOfRange(let min, let max): "Pick a cutoff date between \(min.shortTitle) and \(max.shortTitle)."
        case .hasExpenses(let name, let count): "\(name) has \(count) expense\(count == 1 ? "" : "s") on it, so it can't be deleted."
        }
    }
}

/// One card's bill for one cycle; paying never moves "left to spend", the money was counted when spent.
public struct CardBillLine: Equatable, Sendable {
    public let card: Card
    public let cycleStart: CalendarDate
    public let cycleEnd: CalendarDate
    /// The sum of what each expense on the card really cost in this cycle.
    public let bill: Money
    /// Unpaid balance carried forward from earlier cycles.
    public let carriedOver: Money
    /// What was ticked as paid in this month's cycle.
    public let paid: Money
    /// Cutoff date recorded when paid, if paid.
    public let paidUpTo: CalendarDate?
    /// Net amount still unpaid through `cycleEnd`.
    public let due: Money
    /// New unpaid charges recorded after `cycleEnd` in the next cycle.
    public let newSpend: Money

    public var isPaid: Bool { paid > .zero }
}

public struct CardBills: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    public let lines: [CardBillLine]

    public var totalDue: Money { lines.reduce(.zero) { $0 + $1.due } }
    public var totalNewSpend: Money { lines.reduce(.zero) { $0 + $1.newSpend } }
    public var unpaidCardCount: Int { lines.filter { $0.due > .zero }.count }
    public var hasCardSpending: Bool { lines.contains { $0.bill != .zero || $0.carriedOver != .zero || $0.newSpend != .zero } }

    init(month: CalendarDate.YearMonth, cards: [Card], expenses: [Expense], payments: [CardPayment], today: CalendarDate) {
        self.month = month
        lines = cards.map { card in
            CardCycleBook.line(for: card, month: month, expenses: expenses, payments: payments, today: today)
        }
    }
}

enum CardCycleBook {
    static func defaultEnd(for card: Card, in month: CalendarDate.YearMonth) -> CalendarDate {
        let wanted = min(card.dueDay ?? month.dayCount, month.dayCount)
        return try! CalendarDate(year: month.year, month: month.month, day: wanted)
    }

    static func effectiveEnd(
        for card: Card, in month: CalendarDate.YearMonth, payments: [CalendarDate.YearMonth: CardPayment]
    ) -> CalendarDate {
        payments[month]?.paidUpTo ?? defaultEnd(for: card, in: month)
    }

    static func cycleStart(
        for card: Card, in month: CalendarDate.YearMonth, payments: [CalendarDate.YearMonth: CardPayment]
    ) -> CalendarDate {
        effectiveEnd(for: card, in: month.shifted(by: -1), payments: payments).adding(days: 1)
    }

    static func cutoffBounds(
        for card: Card, in month: CalendarDate.YearMonth, payments: [CardPayment]
    ) -> (min: CalendarDate, max: CalendarDate) {
        let byMonth = Dictionary(uniqueKeysWithValues: payments.filter { $0.cardID == card.id }.map { ($0.month, $0) })
        let minDate = cycleStart(for: card, in: month, payments: byMonth)
        let maxDate = defaultEnd(for: card, in: month.shifted(by: 1)).adding(days: -1)
        return (minDate, maxDate)
    }

    /// Total payment needed in `month` so that every charge on `card` on or before `cutoff` is settled.
    static func paymentNeeded(
        for card: Card, in month: CalendarDate.YearMonth, upTo cutoff: CalendarDate,
        expenses: [Expense], payments: [CardPayment]
    ) -> Money {
        let chargesThroughCutoff = expenses
            .filter { $0.paymentMethod == .bank(card.name) && $0.date <= cutoff }
            .reduce(Money.zero) { $0 + $1.netAmount }
        let paidOtherMonths = payments
            .filter { $0.cardID == card.id && $0.month != month }
            .reduce(Money.zero) { $0 + $1.paid }
        return max(chargesThroughCutoff - paidOtherMonths, .zero)
    }

    static func line(
        for card: Card, month: CalendarDate.YearMonth, expenses: [Expense], payments: [CardPayment], today: CalendarDate
    ) -> CardBillLine {
        let cardExpenses = expenses.filter { $0.paymentMethod == .bank(card.name) }
        let cardPayments = payments.filter { $0.cardID == card.id }
        let byMonth = Dictionary(uniqueKeysWithValues: cardPayments.map { ($0.month, $0) })

        let prevEnd = effectiveEnd(for: card, in: month.shifted(by: -1), payments: byMonth)
        let start = prevEnd.adding(days: 1)
        let end = effectiveEnd(for: card, in: month, payments: byMonth)
        let nextEnd = effectiveEnd(for: card, in: month.shifted(by: 1), payments: byMonth)

        let bill = cardExpenses
            .filter { start <= $0.date && $0.date <= end }
            .reduce(Money.zero) { $0 + $1.netAmount }
        let chargesBefore = cardExpenses
            .filter { $0.date <= prevEnd }
            .reduce(Money.zero) { $0 + $1.netAmount }
        let chargesThroughEnd = chargesBefore + bill

        let paidBefore = cardPayments
            .filter { $0.month < month }
            .reduce(Money.zero) { $0 + $1.paid }
        let totalPaid = cardPayments.reduce(Money.zero) { $0 + $1.paid }
        let paidAfter = cardPayments
            .filter { $0.month > month }
            .reduce(Money.zero) { $0 + $1.paid }

        let carriedOver = max(chargesBefore - paidBefore, .zero)
        let due = max(chargesThroughEnd - totalPaid, .zero)

        let newSpend: Money
        if month == today.yearMonth {
            let chargesNextCycle = cardExpenses
                .filter { end < $0.date && $0.date <= nextEnd }
                .reduce(Money.zero) { $0 + $1.netAmount }
            newSpend = max(chargesNextCycle - paidAfter, .zero)
        } else {
            newSpend = .zero
        }

        let payment = byMonth[month]
        return CardBillLine(
            card: card, cycleStart: start, cycleEnd: end, bill: bill, carriedOver: carriedOver,
            paid: payment?.paid ?? .zero, paidUpTo: payment?.paidUpTo, due: due, newSpend: newSpend
        )
    }
}
