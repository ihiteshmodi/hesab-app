public struct AddIncome: Sendable {
    let income: IncomeRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ new: NewIncome) throws -> IncomeEntry {
        guard let amount = new.amount, amount > .zero else { throw IncomeValidationError.amountMissingOrZero }
        guard let kind = new.kind else { throw IncomeValidationError.typeMissing }
        return try income.add(date: new.date ?? clock.today(), kind: kind, amount: amount, note: new.note.trimmed)
    }
}

public struct DeleteIncome: Sendable {
    let income: IncomeRepository

    public func callAsFunction(_ id: Int64) throws {
        try income.delete(id)
    }
}
