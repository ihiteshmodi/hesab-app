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
    private(set) var loadError: String?
    private var cardMonth: CalendarDate.YearMonth?

    init(app: BudgetApp) {
        self.app = app
        reload()
    }

    func reload() {
        do {
            budget = try app.monthBudget()
            pendingRefunds = try app.pendingRefunds()
            ledgers = try app.ledgers()
            cash = try app.cashInHand()
            cards = try app.cards()
            cardBills = try app.cardBills(for: cardMonth)
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

    func expense(id: Int64) -> Expense? {
        budget?.expenses.first { $0.id == id } ?? pendingRefunds?.expenses.first { $0.id == id }
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
        } catch let error as RefundError {
            return error.message
        } catch let error as LedgerError {
            return error.message
        } catch let error as CardError {
            return error.message
        } catch let error as BackupError {
            return error.message
        } catch {
            return "Could not do that. Try again."
        }
    }
}
