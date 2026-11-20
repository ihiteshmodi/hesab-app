import Foundation

struct TripStore: Sendable {
    let trips: TripRepository
    let expenses: ExpenseRepository
    let clock: any DayClock

    func book(_ tripID: Int64) throws -> TripBook {
        TripBook(
            trip: try trips.trip(tripID), people: try trips.people(of: tripID), groups: try trips.groups(of: tripID),
            expenses: try trips.expenses(of: tripID), settlements: try trips.settlements(of: tripID),
            cashAdjustments: try trips.cashAdjustments(of: tripID), planItems: try trips.planItems(of: tripID)
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
    if let start = trip.startDate, let end = trip.endDate, end < start { throw TripError.endBeforeStart }
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
            category: new.category.trimmed, subCategory: new.subCategory.trimmed, note: new.note.trimmed
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

/// Replaces a saved payment; if the new one is refused, the old one is put back.
public struct UpdateTripSettlement: Sendable {
    let store: TripStore
    let record: RecordTripSettlement

    @discardableResult
    public func callAsFunction(
        _ id: Int64, personID: Int64, _ direction: SettlementDirection, _ amount: Money?,
        method: SettlementMethod = .bank, atRate rate: Decimal? = nil, fullSettlement: Bool = false, on date: CalendarDate? = nil
    ) throws -> TripSettlement {
        let tripID = try store.trips.tripID(ofSettlement: id)
        guard let old = try store.trips.settlements(of: tripID).first(where: { $0.id == id }) else { throw TripError.notFound(id) }
        try store.trips.deleteSettlement(id)
        do {
            return try record(
                tripID, personID: personID, direction, amount, method: method, atRate: rate, fullSettlement: fullSettlement,
                on: date ?? old.date
            )
        } catch {
            _ = try store.trips.addSettlement(
                tripID: tripID, personID: old.personID, date: old.date, direction: old.direction, method: old.method,
                received: old.received, cleared: old.cleared, writtenOff: old.writtenOff
            )
            try store.syncMainLedger(tripID)
            throw error
        }
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

// MARK: trip planner

public struct StartTrip: Sendable {
    let trips: TripRepository

    /// Ends planning: from now on the plan's items can be ticked as paid.
    public func callAsFunction(_ tripID: Int64) throws {
        try trips.startTrip(tripID)
    }
}

/// The total of a new item: typed, or the parts' total when it comes with parts.
private func validated(_ item: NewTripPlanItem) throws -> Money {
    guard !item.description.trimmed.isEmpty else { throw TripError.descriptionMissing }
    if !item.payments.isEmpty {
        for part in item.payments { _ = try validated(part) }
        return item.payments.reduce(.zero) { $0 + ($1.amount ?? .zero) }
    }
    guard let amount = item.amount, amount > .zero else { throw TripError.amountMissingOrZero }
    return amount
}

private func validated(_ part: NewTripPlanPayment) throws -> Money {
    guard let amount = part.amount, amount > .zero else { throw TripError.amountMissingOrZero }
    return amount
}

private func validated(_ leg: NewTripLeg) throws {
    for minutes in [leg.departureMinutes, leg.arrivalMinutes] {
        if let minutes, !(0..<1_440).contains(minutes) { throw TripError.timeInvalid }
    }
    guard let left = leg.departure, let arrival = leg.arrivalDate else { return }
    if arrival < left { throw TripError.legArrivesBeforeLeaving }
    if arrival == left, let leaves = leg.departureMinutes, let arrives = leg.arrivalMinutes, arrives < leaves {
        throw TripError.legArrivesBeforeLeaving
    }
}

private func cleaned(_ part: NewTripPlanPayment) -> NewTripPlanPayment {
    NewTripPlanPayment(label: part.label.trimmed, amount: part.amount, dueDate: part.dueDate)
}

private func cleaned(_ leg: NewTripLeg) -> NewTripLeg {
    var copy = leg
    copy.from = leg.from.trimmed
    copy.to = leg.to.trimmed
    copy.carrier = leg.carrier.trimmed
    copy.number = leg.number.trimmed
    return copy
}

public struct AddTripPlanItem: Sendable {
    let trips: TripRepository

    @discardableResult
    public func callAsFunction(_ tripID: Int64, _ new: NewTripPlanItem) throws -> TripPlanItem {
        _ = try trips.trip(tripID)
        let amount = try validated(new)
        for leg in new.legs { try validated(leg) }
        let tag = new.tag.trimmed
        if !tag.isEmpty { try AddTripTag(trips: trips)(tag) }
        let id = try trips.addPlanItem(
            tripID: tripID, description: new.description.trimmed, amount: amount, tag: tag, category: new.category.trimmed,
            subCategory: new.subCategory.trimmed, note: new.note.trimmed, dueDate: new.dueDate,
            payments: new.payments.map(cleaned), legs: new.legs.map(cleaned)
        )
        return try trips.planItem(id)
    }
}

public struct UpdateTripPlanItem: Sendable {
    let trips: TripRepository

    /// Parts and legs are changed one by one; when the item has parts, its total is theirs and `amount` is not needed.
    public func callAsFunction(_ id: Int64, _ new: NewTripPlanItem) throws {
        let existing = try trips.planItem(id)
        guard !new.description.trimmed.isEmpty else { throw TripError.descriptionMissing }
        var amount = existing.amount
        if existing.payments.isEmpty {
            guard let typed = new.amount, typed > .zero else { throw TripError.amountMissingOrZero }
            amount = typed
        }
        let tag = new.tag.trimmed
        if !tag.isEmpty { try AddTripTag(trips: trips)(tag) }
        try trips.updatePlanItem(
            id, description: new.description.trimmed, amount: amount, tag: tag, category: new.category.trimmed,
            subCategory: new.subCategory.trimmed, note: new.note.trimmed, dueDate: new.dueDate
        )
    }
}

public struct DeleteTripPlanItem: Sendable {
    let trips: TripRepository

    /// A paid item's expense stays; only the plan line goes.
    public func callAsFunction(_ id: Int64) throws {
        try trips.deletePlanItem(id)
    }
}

/// The trip expense a plan item (or one of its parts) becomes: only I share it, so it reaches the main ledger like any other.
private func makeExpense(
    _ item: TripPlanItem, title: String, amount: Money, _ payment: PlanItemPayment, saver: SaveTripExpense
) throws -> TripExpense {
    try saver.save(id: nil, tripID: item.tripID, NewTripExpense(
        description: title, date: payment.date, amount: payment.amount ?? amount, paidWith: payment.paidWith,
        split: .equal([.me]), paidInHome: payment.paidInHome, tag: item.tag, category: item.category,
        subCategory: item.subCategory, note: item.note
    ))
}

public struct MarkTripPlanItemPaid: Sendable {
    let store: TripStore
    let saver: SaveTripExpense

    @discardableResult
    public func callAsFunction(_ id: Int64, _ payment: PlanItemPayment = PlanItemPayment()) throws -> TripExpense {
        let item = try store.trips.planItem(id)
        guard !(try store.trips.trip(item.tripID)).isPlanning else { throw TripError.tripNotStarted }
        guard item.payments.isEmpty else { throw TripError.paidInParts }
        guard !item.isPaid else { throw TripError.alreadyPaid(item.description) }
        let expense = try makeExpense(item, title: item.description, amount: item.amount, payment, saver: saver)
        try store.trips.setPlanItemExpense(id, expense.id)
        return expense
    }
}

public struct UnmarkTripPlanItemPaid: Sendable {
    let store: TripStore

    /// Takes the expense back out, so the item is "still to pay" again.
    public func callAsFunction(_ id: Int64) throws {
        let item = try store.trips.planItem(id)
        guard let expenseID = item.paidExpenseID else { throw TripError.notPaidYet(item.description) }
        try store.trips.deleteExpense(expenseID)
        try store.syncMainLedger(item.tripID)
    }
}

// MARK: paying in parts

public struct AddTripPlanPayment: Sendable {
    let trips: TripRepository

    @discardableResult
    public func callAsFunction(_ itemID: Int64, _ new: NewTripPlanPayment) throws -> TripPlanPayment {
        let item = try trips.planItem(itemID)
        guard !item.isPaid || !item.payments.isEmpty else { throw TripError.itemAlreadyPaid(item.description) }
        _ = try validated(new)
        return try trips.payment(try trips.addPayment(cleaned(new), to: itemID))
    }
}

public struct UpdateTripPlanPayment: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64, _ new: NewTripPlanPayment) throws {
        guard !(try trips.payment(id)).isPaid else { throw TripError.paymentPaid }
        _ = try validated(new)
        try trips.updatePayment(id, cleaned(new))
    }
}

public struct DeleteTripPlanPayment: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64) throws {
        guard !(try trips.payment(id)).isPaid else { throw TripError.paymentPaid }
        try trips.deletePayment(id)
    }
}

public struct MarkTripPlanPaymentPaid: Sendable {
    let store: TripStore
    let saver: SaveTripExpense

    @discardableResult
    public func callAsFunction(_ id: Int64, _ payment: PlanItemPayment = PlanItemPayment()) throws -> TripExpense {
        let part = try store.trips.payment(id)
        let item = try store.trips.planItem(part.itemID)
        guard !(try store.trips.trip(item.tripID)).isPlanning else { throw TripError.tripNotStarted }
        guard !part.isPaid else { throw TripError.alreadyPaid(part.label.isEmpty ? item.description : part.label) }
        let title = part.label.isEmpty ? item.description : "\(item.description) · \(part.label)"
        let expense = try makeExpense(item, title: title, amount: part.amount, payment, saver: saver)
        try store.trips.setPaymentExpense(id, expense.id)
        return expense
    }
}

public struct UnmarkTripPlanPaymentPaid: Sendable {
    let store: TripStore

    public func callAsFunction(_ id: Int64) throws {
        let part = try store.trips.payment(id)
        guard let expenseID = part.paidExpenseID else { throw TripError.notPaidYet(part.label) }
        try store.trips.deleteExpense(expenseID)
        try store.syncMainLedger(try store.trips.planItem(part.itemID).tripID)
    }
}

// MARK: due dates

extension TripStore {
    /// Unpaid payments with a due date on trips that have started and are not settled, soonest first.
    /// `within` keeps those due that many days from today (overdue ones are always kept).
    func dues(within days: Int) throws -> [TripDue] {
        let today = clock.today()
        var found: [TripDue] = []
        for trip in try trips.trips() where !trip.isPlanning && !trip.isSettled {
            let book = try book(trip.id)
            for item in book.planItems {
                let parts: [(paymentID: Int64?, title: String, amount: Money, due: CalendarDate?)] = item.payments.isEmpty
                    ? (item.isPaid ? [] : [(nil, item.description, item.amount, item.dueDate)])
                    : item.payments.filter { !$0.isPaid }.map {
                        ($0.id, $0.label.isEmpty ? item.description : "\(item.description) · \($0.label)", $0.amount, $0.dueDate)
                    }
                for part in parts {
                    guard let due = part.due, today.days(until: due) <= days else { continue }
                    found.append(TripDue(
                        tripID: trip.id, tripName: trip.name, itemID: item.id, paymentID: part.paymentID, title: part.title,
                        amount: part.amount, amountHome: book.homeValue(part.amount), dueDate: due, daysUntil: today.days(until: due),
                        affectsLeftToSpend: trip.paymentMethod.movesLeftToSpend
                    ))
                }
            }
        }
        return found.sorted { ($0.dueDate, $0.title) < ($1.dueDate, $1.title) }
    }
}

public struct GetTripDues: Sendable {
    let store: TripStore
    let settings: SettingsRepository

    /// What is due within the "upcoming" window of Settings, or already overdue.
    public func callAsFunction() throws -> [TripDue] {
        try store.dues(within: Preferences(stored: try settings.all()).upcomingWindowDays)
    }
}

// MARK: travel legs

public struct AddTripLeg: Sendable {
    let trips: TripRepository

    @discardableResult
    public func callAsFunction(_ itemID: Int64, _ new: NewTripLeg) throws -> TripLeg {
        _ = try trips.planItem(itemID)
        try validated(new)
        return try trips.leg(try trips.addLeg(cleaned(new), to: itemID))
    }
}

public struct UpdateTripLeg: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64, _ new: NewTripLeg) throws {
        try validated(new)
        try trips.updateLeg(id, cleaned(new))
    }
}

public struct DeleteTripLeg: Sendable {
    let trips: TripRepository

    public func callAsFunction(_ id: Int64) throws {
        try trips.deleteLeg(id)
    }
}
