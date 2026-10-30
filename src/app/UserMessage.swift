import HisaabCore

/// Every error the core throws for a person to read carries a plain-words `message`.
protocol UserMessage: Error {
    var message: String { get }
}

extension RefundError: UserMessage {}
extension LedgerError: UserMessage {}
extension CardError: UserMessage {}
extension BackupError: UserMessage {}
extension BorrowingError: UserMessage {}
extension ExpenseValidationError: UserMessage {}
extension IncomeValidationError: UserMessage {}
extension CategoryError: UserMessage {}
extension EntityError: UserMessage {}
extension PlannedItemError: UserMessage {}
extension BillError: UserMessage {}
extension CurrencyError: UserMessage {}
extension TripError: UserMessage {}
extension PortfolioError: UserMessage {}
extension PayoutSchemeError: UserMessage {}
