import Foundation
import HisaabCore
import Observation

/// Turns taps and typed text into use-case calls and the answer into something to show.
@MainActor @Observable
final class BudgetViewModel {
    private let app: BudgetApp
    private(set) var budget: MonthBudget?
    private(set) var pendingRefunds: PendingRefunds?
    private(set) var loadError: String?

    init(app: BudgetApp) {
        self.app = app
        reload()
    }

    func reload() {
        do {
            budget = try app.monthBudget()
            pendingRefunds = try app.pendingRefunds()
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

    private func run(_ action: () throws -> Void) -> String? {
        do {
            try action()
            reload()
            return nil
        } catch let error as RefundError {
            return error.message
        } catch {
            return "Could not do that. Try again."
        }
    }
}
