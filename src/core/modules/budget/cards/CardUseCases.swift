private func validateCardInput(_ input: NewCard, excluding id: Int64? = nil, existing: [Card]) throws -> String {
    let name = input.name.trimmed
    guard !name.isEmpty else { throw CardError.nameMissing }
    if let day = input.dueDay, !(1...31).contains(day) { throw CardError.invalidDueDay }
    if let clash = existing.first(where: { $0.id != id && $0.name.lowercased() == name.lowercased() }) {
        throw CardError.nameTaken(clash.name)
    }
    return name
}

public struct AddCard: Sendable {
    let cards: CardRepository

    @discardableResult
    public func callAsFunction(_ new: NewCard) throws -> Card {
        let name = try validateCardInput(new, existing: try cards.all())
        return try cards.add(name: name, dueDay: new.dueDay)
    }
}

public struct UpdateCard: Sendable {
    let cards: CardRepository

    @discardableResult
    public func callAsFunction(_ id: Int64, _ updated: NewCard) throws -> Card {
        _ = try cards.card(id)
        let name = try validateCardInput(updated, excluding: id, existing: try cards.all())
        return try cards.update(id, name: name, dueDay: updated.dueDay)
    }
}

public struct DeleteCard: Sendable {
    let cards: CardRepository
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        let card = try cards.card(id)
        let count = try expenses.all().filter { $0.paymentMethod == .bank(card.name) }.count
        guard count == 0 else { throw CardError.hasExpenses(name: card.name, count: count) }
        try cards.delete(id)
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
        let today = clock.today()
        let month = month ?? today.yearMonth
        return CardBills(
            month: month, cards: try cards.all(), expenses: try expenses.all(),
            payments: try cards.allPayments(), today: today
        )
    }
}

public struct GetCardPaymentAmount: Sendable {
    let cards: CardRepository
    let expenses: ExpenseRepository

    public func callAsFunction(_ cardID: Int64, _ month: CalendarDate.YearMonth, upTo: CalendarDate) throws -> Money {
        let card = try cards.card(cardID)
        let payments = try cards.allPayments()
        let bounds = CardCycleBook.cutoffBounds(for: card, in: month, payments: payments)
        guard bounds.min <= upTo, upTo <= bounds.max else {
            throw CardError.cutoffOutOfRange(min: bounds.min, max: bounds.max)
        }
        return CardCycleBook.paymentNeeded(
            for: card, in: month, upTo: upTo, expenses: try expenses.all(), payments: payments
        )
    }
}

public struct MarkBillPaid: Sendable {
    let cards: CardRepository
    let expenses: ExpenseRepository

    /// Settles the bill up to `upTo` (or the cycle's default due date when omitted).
    public func callAsFunction(_ cardID: Int64, _ month: CalendarDate.YearMonth, upTo: CalendarDate? = nil) throws {
        let card = try cards.card(cardID)
        let payments = try cards.allPayments()
        let cutoff = upTo ?? CardCycleBook.defaultEnd(for: card, in: month)
        let bounds = CardCycleBook.cutoffBounds(for: card, in: month, payments: payments)
        guard bounds.min <= cutoff, cutoff <= bounds.max else {
            throw CardError.cutoffOutOfRange(min: bounds.min, max: bounds.max)
        }
        let needed = CardCycleBook.paymentNeeded(
            for: card, in: month, upTo: cutoff, expenses: try expenses.all(), payments: payments
        )
        guard needed > .zero else { throw CardError.nothingToPay(card: card.name, month: month.title) }
        try cards.setPaid(needed, cardID: cardID, month: month, paidUpTo: cutoff)
    }
}

public struct UnmarkBillPaid: Sendable {
    let cards: CardRepository

    public func callAsFunction(_ cardID: Int64, _ month: CalendarDate.YearMonth) throws {
        try cards.clearPaid(cardID: cardID, month: month)
    }
}
