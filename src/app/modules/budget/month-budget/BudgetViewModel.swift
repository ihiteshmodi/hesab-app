import Foundation
import HisaabCore
import Observation

/// Turns taps and typed text into use-case calls and the answer into something to show.
@MainActor @Observable
final class BudgetViewModel {
    private let app: BudgetApp
    private(set) var budget: MonthBudget?
    private(set) var pendingRefunds: PendingRefunds?
    private(set) var ledgers: LedgerOverview?
    private(set) var cash: CashInHand?
    private(set) var cards: [Card] = []
    private(set) var cardBills: CardBills?
    private(set) var amountToRepay: AmountToRepay?
    private(set) var categories: [CategoryNode] = []
    private(set) var recentCategories: [CategoryChoice] = []
    private(set) var entities: [EntitySummary] = []
    private(set) var planned = PlannedList(items: [])
    private(set) var upcoming = Upcoming(items: [])
    private(set) var bills: [BillSummary] = []
    private(set) var autoAdded: [AutoAddedBill] = []
    private(set) var billsToSend: [BillToSend] = []
    private(set) var attention = BillsAttention(badge: 0, autoAddedUnseen: 0, menuCount: 0)
    private(set) var preferences = Preferences()
    private(set) var currencies: [Currency] = []
    private(set) var searchResults = SearchResults(groups: [], total: .zero)
    private(set) var incomeResults = IncomeSearchResults(entries: [], total: .zero)
    private(set) var trips: [TripSummary] = []
    private(set) var portfolio: Portfolio?
    private(set) var payouts = PayoutOverview(schemes: [], investedTotal: .zero, monthlyPayoutTotal: .zero)
    private(set) var upcomingIncome: [UpcomingIncomeItem] = []
    private(set) var report = Breakdown.empty
    private(set) var reportGrouping = BreakdownGrouping.category
    private(set) var reportMonth = CalendarDate(Date()).yearMonth
    private(set) var reportAllTime = false
    private(set) var spendingPace: SpendingPace?
    private(set) var monthlyTrend: [MonthTrend] = []
    private(set) var vsNormal = SpendingVsNormal(changes: [], hasHistory: false)
    private(set) var categoryTrends: [CategoryTrend] = []
    private(set) var forecast: CashForecast?
    private(set) var netWorthHistory = NetWorthHistory(points: [])
    /// Shown on Activity until dismissed, for example "Added automatically: Internet 800".
    private(set) var notices: [String] = []
    private(set) var loadError: String?
    private var searchText = ""
    private var cardMonth: CalendarDate.YearMonth?
    private var budgetMonth: CalendarDate.YearMonth?

    init(app: BudgetApp) {
        self.app = app
        reload()
    }

    func reload() {
        do {
            budget = try app.monthBudget(for: budgetMonth)
            pendingRefunds = try app.pendingRefunds()
            ledgers = try app.ledgers()
            cash = try app.cashInHand()
            cards = try app.cards()
            cardBills = try app.cardBills(for: cardMonth)
            amountToRepay = try app.amountToRepay()
            categories = try app.categories()
            recentCategories = try app.recentCategories(limit: 3)
            entities = try app.entities()
            planned = try app.plannedItems()
            upcoming = try app.upcoming()
            bills = try app.bills()
            autoAdded = try app.autoAdded()
            billsToSend = try app.billsToSend()
            attention = try app.billsAttention()
            preferences = try app.preferences()
            currencies = try app.currencies()
            trips = try app.trips()
            portfolio = try app.portfolio()
            payouts = try app.payoutSchemes()
            upcomingIncome = try app.upcomingIncome()
            report = try app.spendingBreakdown(reportAllTime ? .allTime : .month(reportMonth), by: reportGrouping)
            spendingPace = try app.spendingPace(for: reportMonth)
            monthlyTrend = try app.monthlyTrend(endingAt: reportMonth)
            vsNormal = try app.spendingVsNormal(for: reportMonth)
            categoryTrends = try app.categoryTrends(endingAt: reportMonth)
            forecast = try app.cashForecast()
            // A failed snapshot must never stop the screens from loading.
            try? app.recordNetWorth()
            netWorthHistory = try app.netWorthHistory()
            runSearch()
            loadError = nil
        } catch {
            loadError = "Could not read your data. Close and reopen the app."
        }
    }

    /// Returns the message to show when the expense is refused, or nil when it was saved.
    func addExpense(_ expense: NewExpense) -> String? {
        do {
            try app.addExpense(expense)
            reload()
            return nil
        } catch let error as ExpenseValidationError {
            return error.message
        } catch {
            return "Could not save this expense. Try again."
        }
    }

    /// Returns the message to show when the entry is refused, or nil when it was saved.
    func addIncome(_ income: NewIncome) -> String? {
        do {
            try app.addIncome(income)
            reload()
            return nil
        } catch let error as IncomeValidationError {
            return error.message
        } catch {
            return "Could not save this entry. Try again."
        }
    }

    func showMonth(_ month: CalendarDate.YearMonth) {
        budgetMonth = month
        reload()
    }

    /// Returns the message to show when the edit is refused, or nil when it was saved.
    func updateExpense(_ id: Int64, _ expense: NewExpense) -> String? {
        run { try app.updateExpense(id, expense) }
    }

    func updateIncome(_ id: Int64, _ income: NewIncome) -> String? { run { try app.updateIncome(id, income) } }
    func deleteIncome(_ id: Int64) -> String? { run { try app.deleteIncome(id) } }
    func markBillSent(_ occurrenceID: Int64, on date: CalendarDate) -> String? { run { try app.markBillSent(occurrenceID, on: date) } }
    func deleteRepayment(_ id: Int64) -> String? { run { try app.deleteRepayment(id) } }

    // MARK: categories and entities

    func addCategory(name: String, colour: String, icon: String) -> String? {
        run { try app.addCategory(NewCategory(name: name, colour: colour, icon: icon)) }
    }

    func addSubCategory(_ parentID: Int64, name: String) -> String? { run { try app.addSubCategory(parentID, name) } }
    func renameCategory(_ id: Int64, to name: String) -> String? { run { try app.renameCategory(id, name) } }
    func renameSubCategory(_ id: Int64, to name: String) -> String? { run { try app.renameSubCategory(id, name) } }
    func mergeSubCategories(_ id: Int64, into target: Int64) -> String? { run { try app.mergeSubCategories(id, into: target) } }
    func deleteCategory(_ id: Int64) -> String? { run { try app.deleteCategory(id) } }
    func deleteSubCategory(_ id: Int64) -> String? { run { try app.deleteSubCategory(id) } }

    func suggestCategory(forDescription text: String) -> CategoryChoice? { try? app.suggestCategory(forDescription: text) }
    func suggestCategory(forEntity name: String) -> CategoryChoice? { try? app.suggestCategory(forEntity: name) }
    func suggestEntities(_ typed: String) -> [String] { (try? app.suggestEntities(typed)) ?? [] }
    func entityLastUse(_ name: String) -> EntityLastUse? { try? app.entityLastUse(forName: name) }
    func entityHistory(_ id: Int64) -> EntityHistory? { try? app.entityHistory(id) }

    func addEntity(name: String) -> String? { run { try app.addEntity(name) } }
    func renameEntity(_ id: Int64, to name: String) -> String? { run { try app.renameEntity(id, to: name) } }
    func mergeEntities(_ id: Int64, into target: Int64) -> String? { run { try app.mergeEntities(id, into: target) } }
    func deleteEntity(_ id: Int64) -> String? { run { try app.deleteEntity(id) } }

    // MARK: planned items and bills

    func addPlanned(description: String, amountText: String) -> String? {
        run { try app.addPlannedItem(NewPlannedItem(description: description, amount: MoneyInput.parse(amountText))) }
    }

    func updatePlanned(_ id: Int64, description: String, amountText: String) -> String? {
        run { try app.updatePlannedItem(id, NewPlannedItem(description: description, amount: MoneyInput.parse(amountText))) }
    }

    func deletePlanned(_ id: Int64) -> String? { run { try app.deletePlannedItem(id) } }
    func addPlannedAsExpense(_ id: Int64, _ expense: NewExpense) -> String? { run { try app.addPlannedAsExpense(id, expense) } }

    func addBill(_ bill: NewBill) -> String? { run { try app.addBill(bill) } }
    func updateBill(_ id: Int64, _ bill: NewBill) -> String? { run { try app.updateBill(id, bill) } }
    func deleteBill(_ id: Int64) -> String? { run { try app.deleteBill(id) } }

    func changeBillPlan(_ id: Int64, endsOn: CalendarDate, startingWith bill: NewBill) -> String? {
        run { try app.changeBillPlan(id, endsOn: endsOn, startingWith: bill) }
    }

    /// Reads the loaded lists first so the calendar redraws whenever they reload.
    func billsCalendar(for month: CalendarDate.YearMonth) -> BillsCalendar? {
        _ = (bills, upcomingIncome, budget)
        return try? app.billsCalendar(for: month)
    }

    func billDraft(_ id: Int64) -> NewExpense? { try? app.billDraft(id) }
    func addBillOccurrence(_ id: Int64, _ expense: NewExpense) -> String? { run { try app.addBillOccurrence(id, expense) } }
    func billsToAdd(for month: CalendarDate.YearMonth) -> [BillChoice] { (try? app.billsToAdd(for: month)) ?? [] }
    func addSeveralBills(_ ids: [Int64], for month: CalendarDate.YearMonth) -> String? { run { try app.addSeveralBills(ids, for: month) } }
    func markAutoAddedSeen() { _ = run { try app.markAutoAddedSeen() } }
    func undoAutoAdded(_ id: Int64) -> String? { run { try app.undoAutoAdded(id) } }

    func dismissNotices() {
        notices = []
        markAutoAddedSeen()
    }

    func lastRate(for currency: String) -> Decimal? { try? app.lastRate(for: currency) }

    func addCurrency(code: String, name: String, symbol: String, decimals: Int) -> String? {
        run { try app.addCurrency(Currency(code: code, name: name, symbol: symbol, decimals: decimals)) }
    }

    func setHomeCurrency(_ code: String) -> String? { run { try app.setHomeCurrency(code) } }

    /// How a foreign amount reads, for example "IDR 150,000".
    func text(_ foreign: ForeignAmount) -> String {
        guard let currency = currencies.first(where: { $0.code == foreign.currency }) else {
            return "\(foreign.currency) \(IndianMoneyFormat.plain(foreign.amount))"
        }
        return CurrencyFormat.string(foreign.amount, in: currency)
    }

    // MARK: trips

    /// Reading `trips` first lets a screen that calls these refresh whenever the data is reloaded.
    func tripSummary(_ id: Int64) -> TripSummary? { _ = trips; return try? app.tripSummary(id) }
    func tripStatement(_ tripID: Int64, _ personID: Int64) -> PersonStatement? { _ = trips; return try? app.tripPersonStatement(tripID, personID) }
    func tripReceipt(_ expenseID: Int64) -> Data? { _ = trips; return (try? app.tripReceipt(expenseID)) ?? nil }
    func tripTags() -> [TripTag] { _ = trips; return (try? app.tripTags()) ?? [] }
    func addPerson(_ tripID: Int64, _ name: String) -> String? { run { try app.addPerson(tripID, name) } }
    func deletePerson(_ tripID: Int64, _ personID: Int64) -> String? { run { try app.deletePerson(tripID, personID) } }
    func saveTripGroup(_ tripID: Int64, id: Int64? = nil, name: String, members: Set<Participant>) -> String? {
        run { try app.saveTripGroup(tripID, id: id, name: name, members: members) }
    }

    func deleteTripGroup(_ id: Int64) -> String? { run { try app.deleteTripGroup(id) } }
    func deleteTripTag(_ name: String) -> String? { run { try app.deleteTripTag(name) } }
    func createTrip(_ trip: NewTrip) -> String? { run { try app.createTrip(trip) } }
    func updateTrip(_ id: Int64, _ trip: NewTrip) -> String? { run { try app.updateTrip(id, trip) } }
    func setTripSettled(_ id: Int64, _ settled: Bool) -> String? { run { try app.setTripSettled(id, settled) } }
    func deleteTrip(_ id: Int64) -> String? { run { try app.deleteTrip(id) } }
    func addTripExpense(_ tripID: Int64, _ expense: NewTripExpense) -> String? { run { try app.addTripExpense(tripID, expense) } }
    func updateTripExpense(_ id: Int64, _ expense: NewTripExpense) -> String? { run { try app.updateTripExpense(id, expense) } }
    func deleteTripExpense(_ id: Int64) -> String? { run { try app.deleteTripExpense(id) } }
    func setTripReceipt(_ expenseID: Int64, _ image: Data?) -> String? { run { try app.setTripReceipt(expenseID, image) } }
    func deleteTripSettlement(_ id: Int64) -> String? { run { try app.deleteTripSettlement(id) } }

    // MARK: trip planner

    func startTrip(_ id: Int64) -> String? { run { try app.startTrip(id) } }
    func deleteTripPlanItem(_ id: Int64) -> String? { run { try app.deleteTripPlanItem(id) } }
    func unmarkTripPlanItemPaid(_ id: Int64) -> String? { run { try app.unmarkTripPlanItemPaid(id) } }

    func addTripPlanItem(_ tripID: Int64, description: String, amountText: String, tag: String, category: String, subCategory: String) -> String? {
        run {
            try app.addTripPlanItem(tripID, NewTripPlanItem(
                description: description, amount: MoneyInput.parse(amountText), tag: tag, category: category, subCategory: subCategory
            ))
        }
    }

    func updateTripPlanItem(_ id: Int64, description: String, amountText: String, tag: String, category: String, subCategory: String) -> String? {
        run {
            try app.updateTripPlanItem(id, NewTripPlanItem(
                description: description, amount: MoneyInput.parse(amountText), tag: tag, category: category, subCategory: subCategory
            ))
        }
    }

    func markTripPlanItemPaid(
        _ id: Int64, amountText: String, date: CalendarDate, paidWith: ExpensePayment, chargeText: String
    ) -> String? {
        guard let amount = MoneyInput.parse(amountText) else { return TripError.amountMissingOrZero.message }
        return run {
            try app.markTripPlanItemPaid(id, PlanItemPayment(
                amount: amount, date: date, paidWith: paidWith,
                paidInHome: chargeText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : MoneyInput.parse(chargeText)
            ))
        }
    }
    func setTripCash(_ tripID: Int64, text: String) -> String? { run { try app.setTripCash(tripID, to: MoneyInput.parse(text)) } }

    func updateTripSettlement(
        _ id: Int64, personID: Int64, _ direction: SettlementDirection, amountText: String, method: SettlementMethod,
        rateText: String, fullSettlement: Bool, on date: CalendarDate
    ) -> String? {
        let rate = Decimal(string: rateText.trimmingCharacters(in: .whitespaces))
        return run {
            try app.updateTripSettlement(
                id, personID: personID, direction, MoneyInput.parse(amountText), method: method, atRate: rate,
                fullSettlement: fullSettlement, on: date
            )
        }
    }

    func recordTripSettlement(
        _ tripID: Int64, personID: Int64, _ direction: SettlementDirection, amountText: String, method: SettlementMethod,
        rateText: String, fullSettlement: Bool, on date: CalendarDate
    ) -> String? {
        let rate = Decimal(string: rateText.trimmingCharacters(in: .whitespaces))
        return run {
            try app.recordTripSettlement(
                tripID, personID: personID, direction, MoneyInput.parse(amountText), method: method, atRate: rate,
                fullSettlement: fullSettlement, on: date
            )
        }
    }

    /// An amount in the trip's currency, for example "IDR 150,000"; the home rupee when the trip has no other currency.
    func tripText(_ money: Money, _ trip: Trip) -> String {
        guard let code = trip.currency else { return IndianMoneyFormat.string(money) }
        guard let currency = currencies.first(where: { $0.code == code }) else {
            return "\(code) \(IndianMoneyFormat.plain(money))"
        }
        return CurrencyFormat.string(money, in: currency)
    }

    // MARK: portfolio and payout schemes

    func setBankBalance(_ text: String) -> String? {
        guard let amount = MoneyInput.parse(text) else { return PortfolioError.amountInvalid.message }
        return run { try app.setBankBalance(amount) }
    }

    func addHolding(_ form: HoldingForm) -> String? { run { try app.addHolding(newHolding(form)) } }
    func updateHolding(_ id: Int64, _ form: HoldingForm) -> String? { run { try app.updateHolding(id, newHolding(form)) } }
    func updateHoldingWorth(_ id: Int64, amountText: String) -> String? {
        run { try app.updateHoldingWorth(id, MoneyInput.parse(amountText)) }
    }

    func addToHolding(_ id: Int64, amountText: String, on date: CalendarDate) -> String? {
        run { try app.addToHolding(id, amount: MoneyInput.parse(amountText), on: date) }
    }

    /// Reads `portfolio` first so the open page redraws after every change.
    func holdingDetail(_ id: Int64) -> HoldingDetail? { _ = portfolio; return try? app.holdingDetail(id) }
    func holdingHistory(_ id: Int64) -> [HoldingPoint] { _ = portfolio; return (try? app.holdingHistory(id)) ?? [] }

    /// An empty "amount invested" box means she does not track what she paid; text that is not a number is passed on as
    /// a negative amount so the core refuses it with its usual message.
    private func newHolding(_ form: HoldingForm) -> NewHolding {
        func optionalMoney(_ text: String, unreadable: Money) -> Money? {
            text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : MoneyInput.parse(text) ?? unreadable
        }
        return NewHolding(
            name: form.name, amount: MoneyInput.parse(form.amountText), currency: form.currency,
            rate: Decimal(string: form.rateText.trimmingCharacters(in: .whitespaces)),
            invested: optionalMoney(form.investedText, unreadable: Money(paise: -1)), investedOn: form.investedOn, kind: form.kind,
            sipAmount: optionalMoney(form.sipAmountText, unreadable: .zero), sipDay: form.sipDay
        )
    }

    func deleteHolding(_ id: Int64) -> String? { run { try app.deleteHolding(id) } }
    func updateAllocatedFund(_ id: Int64, name: String, amountText: String) -> String? {
        run { try app.updateAllocatedFund(id, name: name, amount: MoneyInput.parse(amountText)) }
    }
    func addAllocatedFund(name: String, amountText: String) -> String? { run { try app.addAllocatedFund(name: name, amount: MoneyInput.parse(amountText)) } }
    func deleteAllocatedFund(_ id: Int64) -> String? { run { try app.deleteAllocatedFund(id) } }
    func setLedgerCountsTowardsNetWorth(_ id: Int64, _ counts: Bool) -> String? { run { try app.setLedgerCountsTowardsNetWorth(id, counts) } }
    func addScheme(_ scheme: NewPayoutScheme) -> String? { run { try app.addScheme(scheme) } }
    func updateScheme(_ id: Int64, _ scheme: NewPayoutScheme) -> String? { run { try app.updateScheme(id, scheme) } }
    func payoutDraft(_ id: Int64) -> PayoutDraft? { try? app.payoutDraft(id) }
    func recordPayout(_ id: Int64, amountText: String, on date: CalendarDate, toSavings: Bool = false) -> String? {
        run { try app.recordPayout(id, amount: MoneyInput.parse(amountText), on: date, toSavings: toSavings) }
    }
    func closeScheme(_ id: Int64) -> String? { run { try app.closeScheme(id) } }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        _ = run { try app.updatePreferences(change) }
    }

    /// Looks in the whole book, not the month on screen, so an open expense survives a refund or date change.
    /// Reading `budget` first lets the open screen redraw whenever the data is reloaded.
    func expense(id: Int64) -> Expense? {
        _ = budget
        return (try? app.expense(id)) ?? nil
    }

    func search(_ text: String) {
        searchText = text
        runSearch()
    }

    /// Runs again after every reload so an entry changed from a result does not linger in the list.
    private func runSearch() {
        searchResults = (try? app.searchExpenses(searchText)) ?? SearchResults(groups: [], total: .zero)
        incomeResults = (try? app.searchIncome(searchText)) ?? IncomeSearchResults(entries: [], total: .zero)
    }

    func showReport(grouping: BreakdownGrouping, month: CalendarDate.YearMonth, allTime: Bool) {
        reportGrouping = grouping
        reportMonth = month
        reportAllTime = allTime
        reload()
    }

    /// Reads `report` first so an open row redraws after an expense in it is edited.
    func groupBreakdown(_ grouping: BreakdownGrouping, _ name: String, only: Set<String> = []) -> Breakdown? {
        _ = report
        return try? app.groupBreakdown(grouping, name, reportAllTime ? .allTime : .month(reportMonth), only: only)
    }

    /// Each action returns the message to show when it is refused, or nil when it worked.
    func markRefundable(_ id: Int64) -> String? { run { try app.markRefundable(id) } }
    func undoSettlement(_ id: Int64) -> String? { run { try app.undoSettlement(id) } }
    func unmarkRefundable(_ id: Int64) -> String? { run { try app.unmarkRefundable(id) } }
    func deleteExpense(_ id: Int64) -> String? { run { try app.deleteExpense(id) } }

    func recordReceived(_ id: Int64, amountText: String) -> String? {
        guard let amount = MoneyInput.parse(amountText) else { return "Enter an amount of 0 or more" }
        return run { try app.recordReceived(id, amount) }
    }

    func addLedger(name: String, countsTowardsNetWorth: Bool) -> String? {
        run { try app.addLedger(NewLedger(name: name, countsTowardsNetWorth: countsTowardsNetWorth)) }
    }

    func renameLedger(_ id: Int64, to name: String) -> String? { run { try app.renameLedger(id, name) } }
    func deleteLedger(_ id: Int64) -> String? { run { try app.deleteLedger(id) } }
    func deleteLedgerEntry(_ id: Int64) -> String? { run { try app.deleteLedgerEntry(id) } }

    /// A warning is not a refusal: the entry is saved and the warning is shown beside it.
    func addLedgerEntry(
        _ ledgerID: Int64, description: String, amountText: String, moneyOut: Bool, date: CalendarDate? = nil, editing entryID: Int64? = nil
    ) -> (error: String?, warning: String?) {
        let magnitude = MoneyInput.parse(amountText)
        let value = magnitude.map { moneyOut ? Money.zero - $0 : $0 }
        let new = NewLedgerEntry(date: date, description: description, value: value)
        do {
            let added = try entryID.map { try app.updateLedgerEntry($0, new) } ?? app.addLedgerEntry(ledgerID, new)
            reload()
            return (nil, added.warning)
        } catch let error as LedgerError {
            return (error.message, nil)
        } catch {
            return ("Could not do that. Try again.", nil)
        }
    }

    func setCashInHand(_ amountText: String) -> String? {
        guard let amount = MoneyInput.parse(amountText) else { return "Enter the cash you are holding" }
        return run { try app.setCashInHand(to: amount) }
    }

    func showCardBills(for month: CalendarDate.YearMonth) {
        cardMonth = month
        reload()
    }

    func addCard(name: String) -> String? { run { try app.addCard(NewCard(name: name)) } }

    func recordRepayment(_ borrowingID: Int64, amountText: String, on date: CalendarDate? = nil, fromCash: Bool? = nil) -> String? {
        run { try app.recordRepayment(borrowingID, MoneyInput.parse(amountText), on: date, fromCash: fromCash) }
    }

    func addBorrowing(lender: String, amountText: String, date: CalendarDate, viaCash: Bool) -> String? {
        run { try app.addIncome(NewIncome(date: date, kind: .borrowed, amount: MoneyInput.parse(amountText), note: lender, viaCash: viaCash)) }
    }

    func updateRepayment(_ id: Int64, amountText: String, on date: CalendarDate, fromCash: Bool) -> String? {
        run { try app.updateRepayment(id, amount: MoneyInput.parse(amountText), on: date, fromCash: fromCash) }
    }

    func updateCashAdjustment(_ id: Int64, amountText: String, removed: Bool, title: String, date: CalendarDate) -> String? {
        let amount = MoneyInput.parse(amountText).map { removed ? Money.zero - $0 : $0 }
        return run { try app.updateCashAdjustment(id, amount: amount, note: title, on: date) }
    }

    func deleteCashAdjustment(_ id: Int64) -> String? { run { try app.deleteCashAdjustment(id) } }

    func addCash(amountText: String, title: String, date: CalendarDate) -> String? {
        run { try app.addCash(MoneyInput.parse(amountText), note: title, on: date) }
    }

    /// Writes the export into a fresh temporary folder; the screen hands it to the share sheet.
    func exportData() -> (file: URL?, error: String?) {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return (try app.exportData(into: folder), nil)
        } catch let error as BackupError {
            return (nil, error.message)
        } catch {
            return (nil, "Could not export. Try again.")
        }
    }

    func prepareImport(_ file: URL) -> (preview: ImportPreview?, error: String?) {
        do {
            return (try app.prepareImport(file), nil)
        } catch let error as BackupError {
            return (nil, error.message)
        } catch {
            return (nil, "Could not read that file. Try again.")
        }
    }

    func confirmImport(_ preview: ImportPreview) -> String? {
        run { try app.confirmImport(preview, keepingPreviousIn: try CompositionRoot.backupsFolder()) }
    }

    func setBillPaid(_ cardID: Int64, paid: Bool) -> String? {
        guard let month = cardBills?.month else { return nil }
        return run { paid ? try app.markBillPaid(cardID, month) : try app.unmarkBillPaid(cardID, month) }
    }

    private func run(_ action: () throws -> Void) -> String? {
        do {
            try action()
            reload()
            return nil
        } catch let error as any UserMessage {
            return error.message
        } catch {
            return "Could not do that. Try again."
        }
    }
}

/// What the Add or Edit Investment form holds.
struct HoldingForm {
    var name = ""
    var amountText = ""
    var investedText = ""
    var investedOn: CalendarDate?
    var currency: String?
    var rateText = ""
    var kind = HoldingKind.other
    var sipAmountText = ""
    var sipDay: Int?
}
