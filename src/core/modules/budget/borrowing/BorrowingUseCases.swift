public struct RecordRepayment: Sendable {
    let income: IncomeRepository
    let borrowings: BorrowingRepository
    let clock: any DayClock

    @discardableResult
    public func callAsFunction(_ borrowingID: Int64, _ amount: Money?, on date: CalendarDate? = nil) throws -> Repayment {
        guard let amount, amount > .zero else { throw BorrowingError.amountMissingOrZero }
        guard let loan = try income.all().first(where: { $0.id == borrowingID }) else {
            throw BorrowingError.notFound(borrowingID)
        }
        guard loan.kind == .borrowed else { throw BorrowingError.notABorrowing }
        let owed = AmountToRepay(income: [loan], repayments: try borrowings.all()).total
        guard amount <= owed else { throw BorrowingError.moreThanOwed(owed) }
        return try borrowings.add(borrowingID: borrowingID, date: date ?? clock.today(), amount: amount)
    }
}

public struct GetAmountToRepay: Sendable {
    let income: IncomeRepository
    let borrowings: BorrowingRepository

    public func callAsFunction() throws -> AmountToRepay {
        AmountToRepay(income: try income.all(), repayments: try borrowings.all())
    }
}
