import Foundation

struct TripStore: Sendable {
    let trips: TripRepository
    let expenses: ExpenseRepository
    let clock: any DayClock

    func book(_ tripID: Int64) throws -> TripBook {
        TripBook(
            trip: try trips.trip(tripID), people: try trips.people(of: tripID), groups: try trips.groups(of: tripID),
            expenses: try trips.expenses(of: tripID), settlements: try trips.settlements(of: tripID),
            cashAdjustments: try trips.cashAdjustments(of: tripID)
        )
    }

    /// Keeps the single main-ledger entry in step with the bank and card money the trip has moved.
    func syncMainLedger(_ tripID: Int64) throws {
        let book = try book(tripID)
        let linked = try trips.linkedExpenseID(tripID)
        let amount = book.ledgerAmount
        guard amount > .zero else {
            if let linked { try expenses.delete(linked) }
            try trips.setLinkedExpense(tripID, nil)
            return
        }
        let trip = book.trip
        let lastActivity = (book.expenses.map(\.date) + book.settlements.map(\.date)).max()
        let entry = NewExpense(
            date: trip.endDate ?? lastActivity ?? clock.today(), description: trip.ledgerName, amount: amount,
            category: trip.category, subCategory: trip.subCategory, paymentMethod: trip.paymentMethod
        )
        let expense = try Expense.validated(entry, today: clock.today(), id: linked)
        if let linked {
            try expenses.change(linked) { try $0.edited(to: expense) }
        } else {
            try trips.setLinkedExpense(tripID, try expenses.add(expense).id)
        }
    }
}

private func validated(_ trip: NewTrip) throws -> (name: String, ledgerName: String) {
    let name = trip.name.trimmed
    guard !name.isEmpty else { throw TripError.nameMissing }
    guard !trip.category.isEmpty else { throw TripError.categoryMissing }
    if trip.currency != nil {
        guard let rate = trip.rate else { throw TripError.rateMissing }
        guard rate > 0 else { throw TripError.rateNotPositive }
    }
    let ledgerName = trip.ledgerName.trimmed
    return (name, ledgerName.isEmpty ? "\(name) expenses" : ledgerName)
}

// MARK: people and groups

public struct AddPerson: Sendable {
    let trips: TripRepository

    @discardableResult
    public func callAsFunction(_ tripID: Int64, _ name: String) throws -> Person {
        _ = try trips.trip(tripID)
        let name = name.trimmed
        guard !name.isEmpty else { throw TripError.personNameMissing }
        if let existing = try trips.people(of: tripID).first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw TripError.personNameTaken(existing.name)
        }
        return try trips.addPerson(name, to: tripID)
    }
}

public struct GetPeople: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ tripID: Int64) throws -> [Person] {
        try trips.people(of: tripID)
    }
}

public struct DeletePerson: Sendable {
    let store: TripStore

    public func callAsFunction(_ tripID: Int64, _ personID: Int64) throws {
        let book = try store.book(tripID)
        guard let person = book.people.first(where: { $0.id == personID }) else { return }
        let who = Participant.person(personID)
        let used = book.expenses.contains { $0.paidBy == who || $0.shares[who] != nil }
            || book.settlements.contains { $0.personID == personID }
        if used { throw TripError.personInUse(person.name) }
        try store.trips.deletePerson(personID)
    }
}

public struct SaveTripGroup: Sendable {
    let store: TripStore

    @discardableResult
    public func callAsFunction(_ tripID: Int64, id: Int64? = nil, name: String, members: Set<Participant>) throws -> TripGroup {
        let book = try store.book(tripID)
        let name = name.trimmed
        guard !name.isEmpty else { throw TripError.groupNameMissing }
        if let clash = book.groups.first(where: { $0.name.lowercased() == name.lowercased() && $0.id != id }) {
            throw TripError.groupNameTaken(clash.name)
        }
        guard !members.isEmpty else { throw TripError.nobodySharing }
        let allowed = Set([Participant.me] + book.people.map { Participant.person($0.id) })
        if let outsider = members.first(where: { !allowed.contains($0) }) { throw TripError.notAMember(book.name(of: outsider)) }
        try store.trips.saveGroup(id: id, tripID: tripID, name: name, members: members)
        return try store.trips.groups(of: tripID).first { $0.name == name }!
    }
}

public struct DeleteTripGroup: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64) throws {
        try trips.deleteGroup(id)
    }
}

// MARK: tags

public struct GetTripTags: Sendable {
    let trips: TripRepository

    /// The defaults first, then the ones typed.
    public func callAsFunction() throws -> [TripTag] {
        TripTags.defaults.map { TripTag(name: $0, isDefault: true) } + (try trips.customTags()).map { TripTag(name: $0, isDefault: false) }
    }
}

public struct AddTripTag: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ name: String) throws {
        let name = name.trimmed
        guard !name.isEmpty else { throw TripError.tagMissing }
        guard !TripTags.defaults.contains(where: { $0.lowercased() == name.lowercased() }) else { return }
        try trips.addTag(name)
    }
}

public struct DeleteTripTag: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ name: String) throws {
        if TripTags.defaults.contains(where: { $0.lowercased() == name.lowercased() }) { throw TripError.tagIsDefault(name) }
        try trips.deleteTag(name)
    }
}

// MARK: trips

public struct CreateTrip: Sendable {
    let trips: TripRepository

    @discardableResult
    public func callAsFunction(_ new: NewTrip) throws -> Trip {
        let checked = try validated(new)
        return try trips.insert(new, name: checked.name, ledgerName: checked.ledgerName)
    }
}

public struct UpdateTrip: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64, _ new: NewTrip) throws {
        let checked = try validated(new)
        _ = try store.trips.trip(id)
        try store.trips.update(id, new, name: checked.name, ledgerName: checked.ledgerName)
        try store.syncMainLedger(id)
    }
}

public struct SetTripSettled: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64, _ settled: Bool) throws {
        try trips.setSettled(id, settled)
    }
}

public struct DeleteTrip: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64) throws {
        let linked = try store.trips.linkedExpenseID(id)
        _ = try store.trips.trip(id)
        try store.trips.delete(id)
        if let linked { try store.expenses.delete(linked) }
    }
}

public struct GetTrips: Sendable {
    let store: TripStore

    /// Open trips first, settled ones after, each in the order they were made.
    public func callAsFunction() throws -> [TripSummary] {
        let all = try store.trips.trips().map { try store.book($0.id).summary() }
        return all.filter { !$0.trip.isSettled } + all.filter(\.trip.isSettled)
    }
}

public struct GetTripSummary: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64) throws -> TripSummary {
        try store.book(id).summary()
    }
}

public struct GetTripPersonStatement: Sendable {
    let store: TripStore

    public func callAsFunction(_ tripID: Int64, _ personID: Int64) throws -> PersonStatement {
        guard let statement = try store.book(tripID).statement(for: personID) else {
            throw TripError.notAMember("That person")
        }
        return statement
    }
}

// MARK: expenses

public struct SaveTripExpense: Sendable {
    let store: TripStore

    func save(id: Int64?, tripID: Int64, _ new: NewTripExpense) throws -> TripExpense {
        let book = try store.book(tripID)
        guard !new.description.trimmed.isEmpty else { throw TripError.descriptionMissing }
        guard let amount = new.amount, amount > .zero else { throw TripError.amountMissingOrZero }
        let allowed = Set([Participant.me] + book.people.map { Participant.person($0.id) })
        let shares = try TripSplit.shares(new.split, amount: amount, allowed: allowed, name: book.name(of:))
        guard allowed.contains(new.paidBy) else { throw TripError.notAMember(book.name(of: new.paidBy)) }

        let paidWith = new.paidBy == .me ? new.paidWith : .bank
        let charge = paidWith == .bank && book.trip.currency != nil && new.paidBy == .me ? new.paidInHome : nil
        let tag = new.tag.trimmed
        if !tag.isEmpty { try AddTripTag(trips: store.trips)(tag) }
        let saved = try store.trips.saveExpense(
            id: id, tripID: tripID, description: new.description.trimmed, date: new.date ?? store.clock.today(),
            amount: amount, paidBy: new.paidBy, paidWith: paidWith, shares: shares, paidInHome: charge, tag: tag,
            note: new.note.trimmed
        )
        if id == nil, let receipt = new.receipt { try store.trips.setReceipt(receipt, of: saved.id) }
        try store.syncMainLedger(tripID)
        return try store.trips.expenses(of: tripID).first { $0.id == saved.id }!
    }
}

public struct AddTripExpense: Sendable {
    let saver: SaveTripExpense

    @discardableResult
    public func callAsFunction(_ tripID: Int64, _ new: NewTripExpense) throws -> TripExpense {
        try saver.save(id: nil, tripID: tripID, new)
    }
}

public struct UpdateTripExpense: Sendable {
    let saver: SaveTripExpense

    @discardableResult
    public func callAsFunction(_ id: Int64, _ new: NewTripExpense) throws -> TripExpense {
        try saver.save(id: id, tripID: try saver.store.trips.tripID(ofExpense: id), new)
    }
}

public struct DeleteTripExpense: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64) throws {
        let tripID = try store.trips.tripID(ofExpense: id)
        try store.trips.deleteExpense(id)
        try store.syncMainLedger(tripID)
    }
}

public struct SetTripReceipt: Sendable {
    let trips: TripRepository

    /// Nil removes the photo. The photo is stored as given; shrinking it is the screen's job.
    public func callAsFunction(_ expenseID: Int64, _ image: Data?) throws {
        _ = try trips.tripID(ofExpense: expenseID)
        try trips.setReceipt(image, of: expenseID)
    }
}

public struct GetTripReceipt: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ expenseID: Int64) throws -> Data? {
        try trips.receipt(of: expenseID)
    }
}

// MARK: money between me and one person

public struct RecordTripSettlement: Sendable {
    let store: TripStore

    /// Settles their balance. Only `bank` moves the main ledger; notes move Cash in Hand, trip-currency cash moves the trip's cash.
    /// Rupees clear the balance at `rate` (default: the trip rate). A full settlement clears everything owed and records
    /// the difference as written off: positive when they paid less, negative when they paid more.
    @discardableResult
    public func callAsFunction(
        _ tripID: Int64, personID: Int64, _ direction: SettlementDirection, _ amount: Money?,
        method: SettlementMethod = .bank, atRate rate: Decimal? = nil, fullSettlement: Bool = false, on date: CalendarDate? = nil
    ) throws -> TripSettlement {
        guard let amount, amount > .zero else { throw TripError.amountMissingOrZero }
        let book = try store.book(tripID)
        guard let person = book.people.first(where: { $0.id == personID }) else { throw TripError.notAMember("That person") }
        let balance = book.balance(with: personID)
        let outstanding = direction == .theyPaidMe ? balance : .zero - balance

        let isForeign = book.trip.currency != nil
        let method = !isForeign && method == .cashTrip ? SettlementMethod.cashHome : method
        let value: Money
        if method == .cashTrip || !isForeign {
            value = amount
        } else {
            guard let applied = rate ?? book.trip.rate, applied > 0 else { throw TripError.rateNotPositive }
            value = TripBook.rounded(Decimal(amount.paise) / applied)
        }

        var cleared = value
        var writtenOff = Money.zero
        if fullSettlement {
            guard outstanding > .zero else { throw TripError.nothingToSettle(person.name) }
            cleared = outstanding
            writtenOff = outstanding - value
        }
        let saved = try store.trips.addSettlement(
            tripID: tripID, personID: personID, date: date ?? store.clock.today(), direction: direction, method: method,
            received: amount, cleared: cleared, writtenOff: writtenOff
        )
        try store.syncMainLedger(tripID)
        return saved
    }
}

public struct DeleteTripSettlement: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64) throws {
        let tripID = try store.trips.tripID(ofSettlement: id)
        try store.trips.deleteSettlement(id)
        try store.syncMainLedger(tripID)
    }
}

public struct SetTripCash: Sendable {
    let store: TripStore

    /// Records the difference as an adjustment, so the history still adds up.
    public func callAsFunction(_ tripID: Int64, to target: Money?) throws {
        guard let target, target >= .zero else { throw TripError.amountMissingOrZero }
        let book = try store.book(tripID)
        guard book.trip.currency != nil else { throw TripError.noTripCash }
        let difference = target - book.cash.balance
        guard difference != .zero else { return }
        try store.trips.addCashAdjustment(tripID: tripID, date: store.clock.today(), amount: difference)
    }
}
