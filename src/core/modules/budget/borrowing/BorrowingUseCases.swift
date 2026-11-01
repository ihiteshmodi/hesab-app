public struct RecordRepayment: Sendable {
    let income: IncomeRepository
    let borrowings: BorrowingRepository
    let clock: any DayClock

    @discardableResult
    /// `fromCash` defaults to however the money was borrowed.
    public func callAsFunction(
        _ borrowingID: Int64, _ amount: Money?, on date: CalendarDate? = nil, fromCash: Bool? = nil
    ) throws -> Repayment {
        guard let amount, amount > .zero else { throw BorrowingError.amountMissingOrZero }
        guard let loan = try income.all().first(where: { $0.id == borrowingID }) else {
            throw BorrowingError.notFound(borrowingID)
        }
        guard loan.kind == .borrowed else { throw BorrowingError.notABorrowing }
        let owed = AmountToRepay(income: [loan], repayments: try borrowings.all()).total
        guard amount <= owed else { throw BorrowingError.moreThanOwed(owed) }
        return try borrowings.add(
            borrowingID: borrowingID, date: date ?? clock.today(), amount: amount, fromCash: fromCash ?? loan.viaCash
        )
    }
}

/// Changes a repayment already recorded; it may still not exceed what was owed.
public struct UpdateRepayment: Sendable {
    let income: IncomeRepository
    let borrowings: BorrowingRepository

    public func callAsFunction(_ id: Int64, amount: Money?, on date: CalendarDate?, fromCash: Bool) throws {
        guard let amount, amount > .zero else { throw BorrowingError.amountMissingOrZero }
        let all = try borrowings.all()
        guard let repayment = all.first(where: { $0.id == id }) else { throw BorrowingError.repaymentNotFound(id) }
        guard let loan = try income.all().first(where: { $0.id == repayment.borrowingID }) else {
            throw BorrowingError.notFound(repayment.borrowingID)
        }
        let others = all.filter { $0.borrowingID == loan.id && $0.id != id }
        let owedBeforeThis = loan.amount - others.reduce(Money.zero) { $0 + $1.amount }
        guard amount <= owedBeforeThis else { throw BorrowingError.moreThanOwed(owedBeforeThis) }
        try borrowings.update(id, date: date ?? repayment.date, amount: amount, fromCash: fromCash)
    }
}

public struct DeleteRepayment: Sendable {
    let borrowings: BorrowingRepository

    public func callAsFunction(_ id: Int64) throws {
        try borrowings.delete(id)
    }
}

public struct GetAmountToRepay: Sendable {
    let income: IncomeRepository
    let borrowings: BorrowingRepository

    public func callAsFunction() throws -> AmountToRepay {
        AmountToRepay(income: try income.all(), repayments: try borrowings.all())
    }
}
