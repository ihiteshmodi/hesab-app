public struct AddIncome: Sendable {
    let income: IncomeRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ new: NewIncome) throws -> IncomeEntry {
        guard let amount = new.amount, amount > .zero else { throw IncomeValidationError.amountMissingOrZero }
        guard let kind = new.kind else { throw IncomeValidationError.typeMissing }
        guard kind != .borrowed || !new.note.trimmed.isEmpty else { throw IncomeValidationError.lenderMissing }
        return try income.add(
            date: new.date ?? clock.today(), kind: kind, amount: amount, note: new.note.trimmed,
            viaCash: kind == .borrowed && new.viaCash
        )
    }
}

public struct UpdateIncome: Sendable {
    let income: IncomeRepository
    let clock: any DayClock

    public func callAsFunction(_ id: Int64, _ new: NewIncome) throws {
        guard let amount = new.amount, amount > .zero else { throw IncomeValidationError.amountMissingOrZero }
        guard let kind = new.kind else { throw IncomeValidationError.typeMissing }
        guard kind != .borrowed || !new.note.trimmed.isEmpty else { throw IncomeValidationError.lenderMissing }
        try income.update(
            id, date: new.date ?? clock.today(), kind: kind, amount: amount, note: new.note.trimmed,
            viaCash: kind == .borrowed && new.viaCash
        )
    }
}

public struct DeleteIncome: Sendable {
    let income: IncomeRepository

    public func callAsFunction(_ id: Int64) throws {
        try income.delete(id)
    }
}
