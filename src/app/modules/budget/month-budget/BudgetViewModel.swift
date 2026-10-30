import Foundation
import HisaabCore
import Observation

/// Turns taps and typed text into use-case calls and the answer into something to show.
@MainActor @Observable
final class BudgetViewModel {
    private let app: BudgetApp
    private(set) var budget: MonthBudget?
    private(set) var loadError: String?

    init(app: BudgetApp) {
        self.app = app
        reload()
    }

    func reload() {
        do {
            budget = try app.monthBudget()
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
}
