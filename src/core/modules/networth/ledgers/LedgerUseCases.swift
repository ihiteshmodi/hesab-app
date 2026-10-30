public struct AddLedger: Sendable {
    let ledgers: LedgerRepository

    @discardableResult
    public func callAsFunction(_ new: NewLedger) throws -> Ledger {
        let name = new.name.trimmed
        guard !name.isEmpty else { throw LedgerError.nameMissing }
        if let existing = try ledgers.allLedgers().first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw LedgerError.nameTaken(existing.name)
        }
        return try ledgers.add(new, name: name)
    }
}

public struct DeleteLedger: Sendable {
    let ledgers: LedgerRepository
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws {
        let ledger = try ledgers.ledger(id)
        let paidFromIt = try expenses.all().filter { LedgerBook.isPaidFrom(ledger, $0) }.count
        guard paidFromIt == 0 else { throw LedgerError.hasExpenses(name: ledger.name, count: paidFromIt) }
        try ledgers.delete(id)
    }
}

public struct AddLedgerEntry: Sendable {
    let ledgers: LedgerRepository
    let expenses: ExpenseRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ ledgerID: Int64, _ new: NewLedgerEntry) throws -> LedgerEntryAdded {
        guard let value = new.value, value != .zero else { throw LedgerError.valueMissingOrZero }
        let ledger = try ledgers.ledger(ledgerID)
        let entry = try ledgers.addEntry(
            ledgerID: ledgerID, date: new.date ?? clock.today(), description: new.description.trimmed, amount: value
        )
        let balance = LedgerBook.summaries(
            ledgers: [ledger], entries: try ledgers.allEntries(), expenses: try expenses.all()
        )[0].balance
        let warning = value < .zero && balance < .zero
            ? "You have paid out \(IndianMoneyFormat.plain(.zero - balance)) more than you hold for \(ledger.name)."
            : nil
        return LedgerEntryAdded(entry: entry, warning: warning)
    }
}

public struct DeleteLedgerEntry: Sendable {
    let ledgers: LedgerRepository

    public func callAsFunction(_ id: Int64) throws {
        try ledgers.deleteEntry(id)
    }
}

public struct GetLedgers: Sendable {
    let ledgers: LedgerRepository
    let expenses: ExpenseRepository

    public func callAsFunction() throws -> LedgerOverview {
        let summaries = LedgerBook.summaries(
            ledgers: try ledgers.allLedgers(), entries: try ledgers.allEntries(), expenses: try expenses.all()
        )
        return LedgerOverview(ledgers: summaries, total: summaries.reduce(.zero) { $0 + $1.balance })
    }
}
