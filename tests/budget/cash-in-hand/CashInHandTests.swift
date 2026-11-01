import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/cash-in-hand/cash-in-hand.feature
struct CashInHandTests {
    private func appWithTwentyThousandInTheBank() throws -> BudgetApp {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(20_000)))
        return app
    }

    private func withdraw(_ app: BudgetApp, _ rupees: Int, keep: Bool) throws {
        try app.addExpense(NewExpense(
            description: "ATM", amount: .rupees(rupees), category: "Miscellaneous",
            paymentMethod: .cashWithdrawal, keepAsCash: keep
        ))
    }

    private func spendCash(_ app: BudgetApp, _ rupees: Int, _ name: String = "Chai") throws -> Expense {
        try app.addExpense(NewExpense(
            description: name, amount: .rupees(rupees), category: "Food & Dining", paymentMethod: .cash
        ))
    }

    @Test func withdrawingCashToKeepFillsCashInHandAndLowersLeftToSpend() throws {
        let app = try appWithTwentyThousandInTheBank()

        try withdraw(app, 10_000, keep: true)

        #expect(try app.monthBudget().leftToSpend == .rupees(10_000))
        #expect(try app.cashInHand().balance == .rupees(10_000))
    }

    @Test func withdrawingCashForFamilyLowersLeftToSpendButTracksNoCash() throws {
        let app = try appWithTwentyThousandInTheBank()

        try withdraw(app, 10_000, keep: false)

        #expect(try app.monthBudget().leftToSpend == .rupees(10_000))
        #expect(try app.cashInHand().balance == .zero)
    }

    @Test func keepingCashOnlyMeansSomethingForAWithdrawal() throws {
        let app = try makeApp()

        try app.addExpense(NewExpense(
            description: "Groceries", amount: .rupees(500), category: "Groceries", paymentMethod: .upi, keepAsCash: true
        ))

        #expect(try app.cashInHand().balance == .zero)
    }

    @Test func spendingFromCashLowersCashInHandAndLeavesLeftToSpendAlone() throws {
        let app = try appWithTwentyThousandInTheBank()
        try withdraw(app, 10_000, keep: true)

        try spendCash(app, 450)
        try spendCash(app, 1_200)

        #expect(try app.cashInHand().balance == .rupees(8_350))
        #expect(try app.monthBudget().leftToSpend == .rupees(10_000))
    }

    @Test func correctingTheCashBeingHeldListsAnAdjustment() throws {
        let app = try appWithTwentyThousandInTheBank()
        try withdraw(app, 10_000, keep: true)
        try spendCash(app, 450)
        try spendCash(app, 1_200)

        try app.setCashInHand(to: .rupees(8_000))

        let cash = try app.cashInHand()
        #expect(cash.balance == .rupees(8_000))
        #expect(cash.lines.contains { $0.kind == .adjustment && $0.amount == .rupees(-350) })
    }

    @Test func settingCashToWhatItAlreadyIsAddsNothing() throws {
        let app = try makeApp()

        try app.setCashInHand(to: .zero)

        #expect(try app.cashInHand().lines.isEmpty)
    }

    @Test func spendingMoreCashThanRecordedWarns() throws {
        let app = try makeApp()
        try app.setCashInHand(to: .rupees(100))

        try spendCash(app, 450)

        let cash = try app.cashInHand()
        #expect(cash.balance == .rupees(-350))
        #expect(cash.warning == "You have spent 350 more cash than you have recorded.")
    }

    @Test func deletingACashExpenseReturnsTheCash() throws {
        let app = try appWithTwentyThousandInTheBank()
        try withdraw(app, 10_000, keep: true)
        let chai = try spendCash(app, 450)
        #expect(try app.cashInHand().balance == .rupees(9_550))

        try app.deleteExpense(chai.id!)

        #expect(try app.cashInHand().balance == .rupees(10_000))
    }

    @Test func changingThePaymentMethodMovesTheMoneyBetweenPools() throws {
        let app = try appWithTwentyThousandInTheBank()
        let chai = try app.addExpense(NewExpense(description: "Chai", amount: .rupees(450), category: "Food & Dining"))
        let leftBefore = try app.monthBudget().leftToSpend
        let cashBefore = try app.cashInHand().balance

        try app.updateExpense(chai.id!, NewExpense(
            description: "Chai", amount: .rupees(450), category: "Food & Dining", paymentMethod: .cash
        ))

        #expect(try app.monthBudget().leftToSpend - leftBefore == .rupees(450))
        #expect(cashBefore - (try app.cashInHand().balance) == .rupees(450))
    }

    @Test func deletingAKeptWithdrawalTakesBackTheCashAndGivesBackLeftToSpend() throws {
        let app = try appWithTwentyThousandInTheBank()
        try withdraw(app, 10_000, keep: true)
        let withdrawal = try #require(try app.monthBudget().expenses.first)

        try app.deleteExpense(withdrawal.id!)

        #expect(try app.cashInHand().balance == .zero)
        #expect(try app.monthBudget().leftToSpend == .rupees(20_000))
    }

    @Test func cashInHandListsEachMovementWithTheRunningBalanceOldestFirst() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(20_000)))
        try app.addExpense(NewExpense(
            date: day("2026-10-01"), description: "ATM", amount: .rupees(10_000), category: "Miscellaneous",
            paymentMethod: .cashWithdrawal, keepAsCash: true
        ))
        try app.addExpense(NewExpense(
            date: day("2026-10-05"), description: "Chai", amount: .rupees(450), category: "Food & Dining",
            paymentMethod: .cash
        ))

        let lines = try app.cashInHand().lines

        #expect(lines.map(\.description) == ["ATM", "Chai"])
        #expect(lines.map(\.runningBalance) == [.rupees(10_000), .rupees(9_550)])
    }

    @Test func addingCashWithATitleRaisesCashInHandAndShowsInTheList() throws {
        let app = try makeApp(today: "2026-10-30")

        try app.addCash(.rupees(2_000), note: "Gift from Dad")

        let cash = try app.cashInHand()
        #expect(cash.balance == .rupees(2_000))
        #expect(cash.lines.map(\.description) == ["Gift from Dad"])
        #expect(try app.monthBudget().leftToSpend == .zero)
    }

    @Test func addingCashNeedsAnAmountAboveZero() throws {
        let app = try makeApp()

        #expect(throws: CashError.amountMissingOrZero) { try app.addCash(.zero, note: "x") }
        #expect(throws: CashError.amountMissingOrZero) { try app.addCash(nil, note: "x") }
    }

    @Test func cashAddedByHandCanBeChangedOrDeleted() throws {
        let app = try makeApp(today: "2026-10-30")
        try app.addCash(.rupees(2_000), note: "Gift from Dad")
        let id = try #require(try app.cashInHand().lines.first?.adjustmentID)

        try app.updateCashAdjustment(id, amount: .rupees(2_500), note: "Gift from Dad and Mom", on: day("2026-10-29"))

        let edited = try #require(try app.cashInHand().lines.first)
        #expect(edited.description == "Gift from Dad and Mom")
        #expect(edited.date == day("2026-10-29"))
        #expect(try app.cashInHand().balance == .rupees(2_500))

        try app.deleteCashAdjustment(id)
        #expect(try app.cashInHand().balance == .zero)
    }

    @Test func onlyCashAddedByHandHasAnAdjustmentToChange() throws {
        let app = try appWithTwentyThousandInTheBank()
        try withdraw(app, 5_000, keep: true)

        #expect(try app.cashInHand().lines.compactMap(\.adjustmentID).isEmpty)
    }
}
