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
    public let deleteRepayment: DeleteRepayment
    public let preferences: GetPreferences
    public let updatePreferences: UpdatePreferences
    public let categories: GetCategories
    public let addCategory: AddCategory
    public let addSubCategory: AddSubCategory
    public let renameCategory: RenameCategory
    public let renameSubCategory: RenameSubCategory
    public let mergeSubCategories: MergeSubCategories
    public let deleteCategory: DeleteCategory
    public let deleteSubCategory: DeleteSubCategory
    public let recentCategories: GetRecentCategories
    public let suggestCategory: SuggestCategory
    public let searchCategories: SearchCategories
    public let entities: GetEntities
    public let suggestEntities: SuggestEntities
    public let addEntity: AddEntity
    public let renameEntity: RenameEntity
    public let mergeEntities: MergeEntities
    public let deleteEntity: DeleteEntity
    public let entityLastUse: GetEntityLastUse
    public let entityHistory: GetEntityHistory
    public let addPlannedItem: AddPlannedItem
    public let plannedItems: GetPlannedItems
    public let deletePlannedItem: DeletePlannedItem
    public let addPlannedAsExpense: AddPlannedAsExpense
    public let addBill: AddBill
    public let updateBill: UpdateBill
    public let deleteBill: DeleteBill
    public let changeBillPlan: ChangeBillPlan
    public let bills: GetBills
    public let upcoming: GetUpcoming
    public let billDraft: GetBillDraft
    public let addBillOccurrence: AddBillOccurrence
    public let billsToAdd: GetBillsToAdd
    public let addSeveralBills: AddSeveralBills
    public let runAutomaticBills: RunAutomaticBills
    public let autoAdded: GetAutoAdded
    public let markAutoAddedSeen: MarkAutoAddedSeen
    public let undoAutoAdded: UndoAutoAdded
    public let billsAttention: GetBillsAttention
    public let billsCalendar: GetBillsCalendar
    public let searchExpenses: SearchExpenses
    public let spendingBreakdown: GetSpendingBreakdown
    public let categoryBreakdown: GetCategoryBreakdown
    public let currencies: GetCurrencies
    public let addCurrency: AddCurrency
    public let lastRate: GetLastRate
    public let setHomeCurrency: SetHomeCurrency
    public let portfolio: GetPortfolio
    public let setBankBalance: SetBankBalance
    public let setExchangeRate: SetExchangeRate
    public let addHolding: AddHolding
    public let deleteHolding: DeleteHolding
    public let addAllocatedFund: AddAllocatedFund
    public let deleteAllocatedFund: DeleteAllocatedFund
    public let setLedgerCountsTowardsNetWorth: SetLedgerCountsTowardsNetWorth
    public let addScheme: AddScheme
    public let payoutSchemes: GetPayoutSchemes
    public let upcomingIncome: GetUpcomingIncome
    public let payoutDraft: GetPayoutDraft
    public let recordPayout: RecordPayout
    public let closeScheme: CloseScheme
    public let addPerson: AddPerson
    public let people: GetPeople
    public let deletePerson: DeletePerson
    public let saveTripGroup: SaveTripGroup
    public let deleteTripGroup: DeleteTripGroup
    public let tripTags: GetTripTags
    public let addTripTag: AddTripTag
    public let deleteTripTag: DeleteTripTag
    public let createTrip: CreateTrip
    public let updateTrip: UpdateTrip
    public let setTripSettled: SetTripSettled
    public let deleteTrip: DeleteTrip
    public let trips: GetTrips
    public let tripSummary: GetTripSummary
    public let tripPersonStatement: GetTripPersonStatement
    public let addTripExpense: AddTripExpense
    public let updateTripExpense: UpdateTripExpense
    public let deleteTripExpense: DeleteTripExpense
    public let setTripReceipt: SetTripReceipt
    public let tripReceipt: GetTripReceipt
    public let recordTripSettlement: RecordTripSettlement
    public let deleteTripSettlement: DeleteTripSettlement
    public let setTripCash: SetTripCash

    public init(database: AppDatabase, clock: any DayClock) {
        let expenses = ExpenseRepository(database: database)
        let income = IncomeRepository(database: database)
        let ledgerBook = LedgerRepository(database: database)
        let cash = CashAdjustmentRepository(database: database)
        let tripBook = TripRepository(database: database)
        let borrowingBook = BorrowingRepository(database: database)
        let settingsBook = SettingsRepository(database: database)
        let schemeBook = PayoutSchemeRepository(database: database)
        let schemeStore = SchemeStore(schemes: schemeBook, settings: settingsBook, clock: clock)
        addLedger = AddLedger(ledgers: ledgerBook)
        deleteLedger = DeleteLedger(ledgers: ledgerBook, expenses: expenses)
        addLedgerEntry = AddLedgerEntry(ledgers: ledgerBook, expenses: expenses, clock: clock)
        deleteLedgerEntry = DeleteLedgerEntry(ledgers: ledgerBook)
        ledgers = GetLedgers(ledgers: ledgerBook, expenses: expenses)
        cashInHand = GetCashInHand(expenses: expenses, adjustments: cash, trips: tripBook)
        setCashInHand = SetCashInHand(expenses: expenses, adjustments: cash, trips: tripBook, clock: clock)
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
        monthBudget = GetMonthBudget(expenses: expenses, income: income, repayments: borrowingBook, settings: settingsBook, clock: clock)
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
        deleteRepayment = DeleteRepayment(borrowings: borrowingBook)
        preferences = GetPreferences(settings: settingsBook)
        updatePreferences = UpdatePreferences(settings: settingsBook)
        let categoryBook = CategoryRepository(database: database)
        categories = GetCategories(categories: categoryBook)
        addCategory = AddCategory(categories: categoryBook)
        addSubCategory = AddSubCategory(categories: categoryBook)
        renameCategory = RenameCategory(categories: categoryBook)
        renameSubCategory = RenameSubCategory(categories: categoryBook)
        mergeSubCategories = MergeSubCategories(categories: categoryBook)
        deleteCategory = DeleteCategory(categories: categoryBook)
        deleteSubCategory = DeleteSubCategory(categories: categoryBook)
        recentCategories = GetRecentCategories(categories: categoryBook)
        suggestCategory = SuggestCategory(categories: categoryBook)
        searchCategories = SearchCategories(categories: categoryBook)
        let entityBook = EntityRepository(database: database)
        entities = GetEntities(entities: entityBook)
        suggestEntities = SuggestEntities(entities: entityBook)
        addEntity = AddEntity(entities: entityBook)
        renameEntity = RenameEntity(entities: entityBook)
        mergeEntities = MergeEntities(entities: entityBook)
        deleteEntity = DeleteEntity(entities: entityBook)
        entityLastUse = GetEntityLastUse(entities: entityBook)
        entityHistory = GetEntityHistory(entities: entityBook, expenses: expenses)
        let plannedBook = PlannedRepository(database: database)
        addPlannedItem = AddPlannedItem(planned: plannedBook)
        plannedItems = GetPlannedItems(planned: plannedBook)
        deletePlannedItem = DeletePlannedItem(planned: plannedBook)
        addPlannedAsExpense = AddPlannedAsExpense(planned: plannedBook, addExpense: addExpense)
        let billBook = BillRepository(database: database)
        let billStore = BillStore(bills: billBook, settings: settingsBook, clock: clock)
        addBill = AddBill(bills: billBook)
        updateBill = UpdateBill(bills: billBook)
        deleteBill = DeleteBill(bills: billBook)
        changeBillPlan = ChangeBillPlan(bills: billBook)
        bills = GetBills(store: billStore)
        upcoming = GetUpcoming(store: billStore)
        billDraft = GetBillDraft(store: billStore)
        addBillOccurrence = AddBillOccurrence(store: billStore, addExpense: addExpense)
        billsToAdd = GetBillsToAdd(store: billStore)
        addSeveralBills = AddSeveralBills(store: billStore, addExpense: addExpense)
        runAutomaticBills = RunAutomaticBills(store: billStore, addExpense: addExpense)
        autoAdded = GetAutoAdded(store: billStore, expenses: expenses)
        markAutoAddedSeen = MarkAutoAddedSeen(bills: billBook)
        undoAutoAdded = UndoAutoAdded(store: billStore, expenses: expenses)
        billsAttention = GetBillsAttention(store: billStore, schemes: schemeStore)
        billsCalendar = GetBillsCalendar(store: billStore, schemes: schemeStore, income: income)
        searchExpenses = SearchExpenses(expenses: expenses)
        spendingBreakdown = GetSpendingBreakdown(expenses: expenses)
        categoryBreakdown = GetCategoryBreakdown(expenses: expenses)
        let currencyBook = CurrencyRepository(database: database)
        currencies = GetCurrencies(currencies: currencyBook)
        addCurrency = AddCurrency(currencies: currencyBook)
        lastRate = GetLastRate(expenses: expenses)
        setHomeCurrency = SetHomeCurrency(expenses: expenses, income: income, settings: settingsBook)
        let portfolioBook = PortfolioRepository(database: database, settings: settingsBook)
        portfolio = GetPortfolio(portfolio: portfolioBook, ledgers: ledgerBook, expenses: expenses, schemes: schemeBook)
        setBankBalance = SetBankBalance(portfolio: portfolioBook, clock: clock)
        setExchangeRate = SetExchangeRate(portfolio: portfolioBook, clock: clock)
        addHolding = AddHolding(portfolio: portfolioBook, setRate: setExchangeRate)
        deleteHolding = DeleteHolding(portfolio: portfolioBook)
        addAllocatedFund = AddAllocatedFund(portfolio: portfolioBook)
        deleteAllocatedFund = DeleteAllocatedFund(portfolio: portfolioBook)
        setLedgerCountsTowardsNetWorth = SetLedgerCountsTowardsNetWorth(ledgers: ledgerBook)
        addScheme = AddScheme(schemes: schemeBook)
        payoutSchemes = GetPayoutSchemes(schemes: schemeBook)
        upcomingIncome = GetUpcomingIncome(store: schemeStore)
        payoutDraft = GetPayoutDraft(store: schemeStore)
        recordPayout = RecordPayout(store: schemeStore, income: income)
        closeScheme = CloseScheme(schemes: schemeBook)
        let tripStore = TripStore(trips: tripBook, expenses: expenses, clock: clock)
        addPerson = AddPerson(trips: tripBook)
        people = GetPeople(trips: tripBook)
        deletePerson = DeletePerson(store: tripStore)
        saveTripGroup = SaveTripGroup(store: tripStore)
        deleteTripGroup = DeleteTripGroup(trips: tripBook)
        tripTags = GetTripTags(trips: tripBook)
        addTripTag = AddTripTag(trips: tripBook)
        deleteTripTag = DeleteTripTag(trips: tripBook)
        createTrip = CreateTrip(trips: tripBook)
        updateTrip = UpdateTrip(store: tripStore)
        setTripSettled = SetTripSettled(trips: tripBook)
        deleteTrip = DeleteTrip(store: tripStore)
        trips = GetTrips(store: tripStore)
        tripSummary = GetTripSummary(store: tripStore)
        tripPersonStatement = GetTripPersonStatement(store: tripStore)
        let tripSaver = SaveTripExpense(store: tripStore)
        addTripExpense = AddTripExpense(saver: tripSaver)
        updateTripExpense = UpdateTripExpense(saver: tripSaver)
        deleteTripExpense = DeleteTripExpense(store: tripStore)
        setTripReceipt = SetTripReceipt(trips: tripBook)
        tripReceipt = GetTripReceipt(trips: tripBook)
        recordTripSettlement = RecordTripSettlement(store: tripStore)
        deleteTripSettlement = DeleteTripSettlement(store: tripStore)
        setTripCash = SetTripCash(store: tripStore)
    }
}
