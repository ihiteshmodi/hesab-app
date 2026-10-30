public struct AddCard: Sendable {
    let cards: CardRepository

    @discardableResult
    public func callAsFunction(_ new: NewCard) throws -> Card {
        let name = new.name.trimmed
        guard !name.isEmpty else { throw CardError.nameMissing }
        if let existing = try cards.all().first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CardError.nameTaken(existing.name)
        }
        return try cards.add(name: name)
    }
}

public struct GetCards: Sendable {
    let cards: CardRepository

    public func callAsFunction() throws -> [Card] {
        try cards.all()
    }
}

public struct GetCardBills: Sendable {
    let cards: CardRepository
    let expenses: ExpenseRepository
    let clock: any DayClock

    /// Defaults to the month containing today.
    public func callAsFunction(for month: CalendarDate.YearMonth? = nil) throws -> CardBills {
        let month = month ?? clock.today().yearMonth
        return CardBills(
            month: month, cards: try cards.all(), expenses: try expenses.all(), paid: try cards.paid(in: month)
        )
    }
}

public struct MarkBillPaid: Sendable {
    let cards: CardRepository
    let bills: GetCardBills

    /// Settles the bill as it stands now; ticking again later settles what was added since.
    public func callAsFunction(_ cardID: Int64, _ month: CalendarDate.YearMonth) throws {
        let card = try cards.card(cardID)
        let bill = try bills(for: month).lines.first { $0.card == card }?.bill ?? .zero
        guard bill > .zero else { throw CardError.nothingToPay(card: card.name, month: month.title) }
        try cards.setPaid(bill, cardID: cardID, month: month)
    }
}

public struct UnmarkBillPaid: Sendable {
    let cards: CardRepository

    public func callAsFunction(_ cardID: Int64, _ month: CalendarDate.YearMonth) throws {
        try cards.clearPaid(cardID: cardID, month: month)
    }
}
