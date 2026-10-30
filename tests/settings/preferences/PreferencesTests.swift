import Testing
@testable import HisaabCore

/// Scenarios from tests/settings/preferences/preferences.feature (the totals and defaults).
struct PreferencesTests {
    private func spend(_ app: BudgetApp, _ rupees: Int, on method: PaymentMethod) throws {
        try app.addExpense(NewExpense(
            date: day("2026-10-12"), description: "Item", amount: .rupees(rupees), category: "Groceries",
            paymentMethod: method
        ))
    }

    @Test func aFreshInstallHasTheDocumentedDefaults() throws {
        let preferences = try makeApp().preferences()

        #expect(preferences.upcomingWindowDays == 14)
        #expect(preferences.paymentDate == .useDueDate)
        #expect(!preferences.showExactDays)
        #expect(preferences.includePastDue)
        #expect(preferences.payoutAlertDays == 5)
        #expect(preferences.countMoneyReceivedAsIncome)
        #expect(!preferences.countBorrowedAsIncome)
        #expect(!preferences.includeCashAndLedgerInSpent)
        #expect(!preferences.hideBalances)
        #expect(!preferences.appLock)
        #expect(preferences.homeCurrency == "INR")
    }

    @Test func changedPreferencesAreRemembered() throws {
        let app = try makeApp()

        try app.updatePreferences {
            $0.upcomingWindowDays = 30
            $0.paymentDate = .askEachTime
            $0.showExactDays = true
            $0.includePastDue = false
            $0.hideBalances = true
            $0.homeCurrency = "USD"
        }

        let saved = try app.preferences()
        #expect(saved.upcomingWindowDays == 30)
        #expect(saved.paymentDate == .askEachTime)
        #expect(saved.showExactDays)
        #expect(!saved.includePastDue)
        #expect(saved.hideBalances)
        #expect(saved.homeCurrency == "USD")
    }

    @Test func updatingTwiceKeepsTheLatestValue() throws {
        let app = try makeApp()
        try app.updatePreferences { $0.payoutAlertDays = 3 }

        try app.updatePreferences { $0.payoutAlertDays = 7 }

        #expect(try app.preferences().payoutAlertDays == 7)
    }

    @Test func moneyReceivedCanBeLeftOutOfIncome() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(1_000)))
        try app.addIncome(NewIncome(kind: .moneyReceived, amount: .rupees(200), note: "Ben"))
        #expect(try app.monthBudget().incomeThisMonth == .rupees(1_200))

        try app.updatePreferences { $0.countMoneyReceivedAsIncome = false }

        #expect(try app.monthBudget().incomeThisMonth == .rupees(1_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(1_200))
    }

    @Test func borrowedMoneyCanBeCountedAsIncome() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(500), note: "Ben"))
        #expect(try app.monthBudget().incomeThisMonth == .zero)

        try app.updatePreferences { $0.countBorrowedAsIncome = true }

        #expect(try app.monthBudget().incomeThisMonth == .rupees(500))
    }

    @Test func cashAndLedgerSpendingCanBeIncludedInSpentThisMonth() throws {
        let app = try makeApp()
        let aunt = try app.addLedger(NewLedger(name: "Aunt"))
        try spend(app, 1_000, on: .upi)
        try spend(app, 100, on: .cash)
        try spend(app, 50, on: .ledger(aunt.name))
        #expect(try app.monthBudget(for: .init(year: 2026, month: 10)).spentThisMonth == .rupees(1_000))

        try app.updatePreferences { $0.includeCashAndLedgerInSpent = true }

        #expect(try app.monthBudget(for: .init(year: 2026, month: 10)).spentThisMonth == .rupees(1_150))
        #expect(try app.monthBudget().leftToSpend == .rupees(-1_000))
    }
}
