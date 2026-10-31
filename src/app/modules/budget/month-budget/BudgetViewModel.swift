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
    private(set) var attention = BillsAttention(badge: 0, autoAddedUnseen: 0, menuCount: 0)
    private(set) var preferences = Preferences()
    private(set) var currencies: [Currency] = []
    private(set) var searchResults = SearchResults(groups: [], total: .zero)
    private(set) var trips: [TripSummary] = []
    private(set) var portfolio: Portfolio?
    private(set) var payouts = PayoutOverview(schemes: [], investedTotal: .zero, monthlyPayoutTotal: .zero)
    private(set) var upcomingIncome: [UpcomingIncomeItem] = []
    private(set) var report = Breakdown.empty
    private(set) var reportGrouping = BreakdownGrouping.category
    private(set) var reportMonth = CalendarDate(Date()).yearMonth
    private(set) var reportAllTime = false
    /// Shown on Activity until dismissed, for example "Added automatically: Internet 800".
    private(set) var notices: [String] = []
    private(set) var loadError: String?
    private var cardMonth: CalendarDate.YearMonth?
    private var budgetMonth: CalendarDate.YearMonth?

    init(app: BudgetApp) {
        self.app = app
        notices = (try? app.runAutomaticBills()) ?? []
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
            attention = try app.billsAttention()
            preferences = try app.preferences()
            currencies = try app.currencies()
            trips = try app.trips()
            portfolio = try app.portfolio()
            payouts = try app.payoutSchemes()
            upcomingIncome = try app.upcomingIncome()
            report = try app.spendingBreakdown(reportAllTime ? .allTime : .month(reportMonth), by: reportGrouping)
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

    func deleteIncome(_ id: Int64) -> String? { run { try app.deleteIncome(id) } }
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

    func deletePlanned(_ id: Int64) -> String? { run { try app.deletePlannedItem(id) } }
    func addPlannedAsExpense(_ id: Int64, _ expense: NewExpense) -> String? { run { try app.addPlannedAsExpense(id, expense) } }

    /// A bill that adds itself and is already due goes in at once, so it never waits for the next launch.
    func addBill(_ bill: NewBill) -> String? { run { try app.addBill(bill); notices += try app.runAutomaticBills() } }
    func updateBill(_ id: Int64, _ bill: NewBill) -> String? {
        run { try app.updateBill(id, bill); notices += try app.runAutomaticBills() }
    }
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
    func setTripCash(_ tripID: Int64, text: String) -> String? { run { try app.setTripCash(tripID, to: MoneyInput.parse(text)) } }

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

    func addHolding(name: String, amountText: String, currency: String?, rateText: String) -> String? {
        run {
            try app.addHolding(NewHolding(
                name: name, amount: MoneyInput.parse(amountText), currency: currency,
                rate: Decimal(string: rateText.trimmingCharacters(in: .whitespaces))
            ))
        }
    }

    func deleteHolding(_ id: Int64) -> String? { run { try app.deleteHolding(id) } }
    func addAllocatedFund(name: String, amountText: String) -> String? { run { try app.addAllocatedFund(name: name, amount: MoneyInput.parse(amountText)) } }
    func deleteAllocatedFund(_ id: Int64) -> String? { run { try app.deleteAllocatedFund(id) } }
    func setLedgerCountsTowardsNetWorth(_ id: Int64, _ counts: Bool) -> String? { run { try app.setLedgerCountsTowardsNetWorth(id, counts) } }
    func addScheme(_ scheme: NewPayoutScheme) -> String? { run { try app.addScheme(scheme) } }
    func payoutDraft(_ id: Int64) -> PayoutDraft? { try? app.payoutDraft(id) }
    func recordPayout(_ id: Int64, amountText: String, on date: CalendarDate) -> String? { run { try app.recordPayout(id, amount: MoneyInput.parse(amountText), on: date) } }
    func closeScheme(_ id: Int64) -> String? { run { try app.closeScheme(id) } }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        _ = run { try app.updatePreferences(change) }
    }

    func expense(id: Int64) -> Expense? {
        budget?.expenses.first { $0.id == id } ?? pendingRefunds?.expenses.first { $0.id == id }
            ?? searchResults.groups.flatMap(\.expenses).first { $0.id == id }
    }

    func search(_ text: String) {
        searchResults = (try? app.searchExpenses(text)) ?? SearchResults(groups: [], total: .zero)
    }

    func showReport(grouping: BreakdownGrouping, month: CalendarDate.YearMonth, allTime: Bool) {
        reportGrouping = grouping
        reportMonth = month
        reportAllTime = allTime
        reload()
    }

    func categoryBreakdown(_ category: String) -> Breakdown? {
        try? app.categoryBreakdown(category, reportAllTime ? .allTime : .month(reportMonth))
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

    func deleteLedger(_ id: Int64) -> String? { run { try app.deleteLedger(id) } }
    func deleteLedgerEntry(_ id: Int64) -> String? { run { try app.deleteLedgerEntry(id) } }

    /// A warning is not a refusal: the entry is saved and the warning is shown beside it.
    func addLedgerEntry(_ ledgerID: Int64, description: String, amountText: String, moneyOut: Bool) -> (error: String?, warning: String?) {
        let magnitude = MoneyInput.parse(amountText)
        let value = magnitude.map { moneyOut ? Money.zero - $0 : $0 }
        do {
            let added = try app.addLedgerEntry(ledgerID, NewLedgerEntry(description: description, value: value))
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

    func recordRepayment(_ borrowingID: Int64, amountText: String) -> String? {
        run { try app.recordRepayment(borrowingID, MoneyInput.parse(amountText)) }
    }

    /// Writes the export into the temporary folder; the screen hands it to the system file saver.
    func exportData() -> (file: URL?, error: String?) {
        do {
            return (try app.exportData(into: FileManager.default.temporaryDirectory), nil)
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
