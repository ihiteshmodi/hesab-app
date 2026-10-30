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

    func addBill(_ bill: NewBill) -> String? { run { try app.addBill(bill) } }
    func updateBill(_ id: Int64, _ bill: NewBill) -> String? { run { try app.updateBill(id, bill) } }
    func deleteBill(_ id: Int64) -> String? { run { try app.deleteBill(id) } }

    func changeBillPlan(_ id: Int64, endsOn: CalendarDate, startingWith bill: NewBill) -> String? {
        run { try app.changeBillPlan(id, endsOn: endsOn, startingWith: bill) }
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
