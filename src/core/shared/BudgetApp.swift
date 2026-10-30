/// The application interface: screens and tests use the app through these use cases only.
public final class BudgetApp: Sendable {
    public let addExpense: AddExpense
    public let updateExpense: UpdateExpense
    public let deleteExpense: DeleteExpense
    public let markRefundable: MarkRefundable
    public let recordReceived: RecordReceived
    public let undoSettlement: UndoSettlement
    public let unmarkRefundable: UnmarkRefundable
    public let pendingRefunds: GetPendingRefunds
    public let addIncome: AddIncome
    public let addLedger: AddLedger
    public let deleteLedger: DeleteLedger
    public let addLedgerEntry: AddLedgerEntry
    public let deleteLedgerEntry: DeleteLedgerEntry
    public let ledgers: GetLedgers
    public let cashInHand: GetCashInHand
    public let setCashInHand: SetCashInHand
    public let deleteIncome: DeleteIncome
    public let monthBudget: GetMonthBudget
    public let addCard: AddCard
    public let cards: GetCards
    public let cardBills: GetCardBills
    public let markBillPaid: MarkBillPaid
    public let unmarkBillPaid: UnmarkBillPaid
    public let exportData: ExportData
    public let prepareImport: PrepareImport
    public let confirmImport: ConfirmImport
    public let recordRepayment: RecordRepayment
    public let amountToRepay: GetAmountToRepay

    public init(database: AppDatabase, clock: any DayClock) {
        let expenses = ExpenseRepository(database: database)
        let income = IncomeRepository(database: database)
        let ledgerBook = LedgerRepository(database: database)
        let cash = CashAdjustmentRepository(database: database)
        let borrowingBook = BorrowingRepository(database: database)
        addLedger = AddLedger(ledgers: ledgerBook)
        deleteLedger = DeleteLedger(ledgers: ledgerBook, expenses: expenses)
        addLedgerEntry = AddLedgerEntry(ledgers: ledgerBook, expenses: expenses, clock: clock)
        deleteLedgerEntry = DeleteLedgerEntry(ledgers: ledgerBook)
        ledgers = GetLedgers(ledgers: ledgerBook, expenses: expenses)
        cashInHand = GetCashInHand(expenses: expenses, adjustments: cash)
        setCashInHand = SetCashInHand(expenses: expenses, adjustments: cash, clock: clock)
        addExpense = AddExpense(expenses: expenses, clock: clock)
        updateExpense = UpdateExpense(expenses: expenses, clock: clock)
        deleteExpense = DeleteExpense(expenses: expenses)
        markRefundable = MarkRefundable(expenses: expenses)
        recordReceived = RecordReceived(expenses: expenses)
        undoSettlement = UndoSettlement(expenses: expenses)
        unmarkRefundable = UnmarkRefundable(expenses: expenses)
        pendingRefunds = GetPendingRefunds(expenses: expenses)
        addIncome = AddIncome(income: income, clock: clock)
        deleteIncome = DeleteIncome(income: income)
        monthBudget = GetMonthBudget(expenses: expenses, income: income, repayments: borrowingBook, clock: clock)
        let cardBook = CardRepository(database: database)
        addCard = AddCard(cards: cardBook)
        cards = GetCards(cards: cardBook)
        cardBills = GetCardBills(cards: cardBook, expenses: expenses, clock: clock)
        markBillPaid = MarkBillPaid(cards: cardBook, bills: cardBills)
        unmarkBillPaid = UnmarkBillPaid(cards: cardBook)
        exportData = ExportData(database: database, clock: clock)
        prepareImport = PrepareImport(database: database)
        confirmImport = ConfirmImport(database: database, clock: clock)
        recordRepayment = RecordRepayment(income: income, borrowings: borrowingBook, clock: clock)
        amountToRepay = GetAmountToRepay(income: income, borrowings: borrowingBook)
    }
}
