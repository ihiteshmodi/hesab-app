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
