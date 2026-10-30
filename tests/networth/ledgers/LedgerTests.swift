import Testing
@testable import HisaabCore

/// Scenarios from tests/networth/ledgers/ledgers.feature
struct LedgerTests {
    @discardableResult
    private func ledger(_ app: BudgetApp, _ name: String, countsTowardsNetWorth: Bool = false) throws -> Ledger {
        try app.addLedger(NewLedger(name: name, countsTowardsNetWorth: countsTowardsNetWorth))
    }

    @discardableResult
    private func entry(_ app: BudgetApp, _ ledger: Ledger, _ text: String, _ rupees: Int) throws -> LedgerEntryAdded {
        try app.addLedgerEntry(ledger.id, NewLedgerEntry(description: text, value: .rupees(rupees)))
    }

    private func balance(_ app: BudgetApp, _ ledger: Ledger) throws -> Money {
        try #require(try app.ledgers().ledgers.first { $0.ledger.id == ledger.id }).balance
    }

    @Test func aLedgerBalanceIsTheSumOfItsEntries() throws {
        let app = try makeApp()
        let mom = try ledger(app, "Mom")
        try entry(app, mom, "Carry over", 60_000)

        try entry(app, mom, "Withdrawal", -10_000)

        #expect(try balance(app, mom) == .rupees(50_000))
    }

    @Test func aNewLedgerStartsAtZeroAndRemembersWhetherItCountsTowardsNetWorth() throws {
        let app = try makeApp()

        let aunt = try ledger(app, "Aunt", countsTowardsNetWorth: true)

        let summary = try #require(try app.ledgers().ledgers.first)
        #expect(summary.ledger == aunt)
        #expect(summary.ledger.countsTowardsNetWorth)
        #expect(summary.balance == .zero)
    }

    @Test func theTotalHeldForOthersIsTheSumOfEveryLedger() throws {
        let app = try makeApp()
        for (name, rupees) in [("Mom", 50_000), ("Sam", 70_000), ("Neighbor", 28_000)] {
            try entry(app, try ledger(app, name), "Opening", rupees)
        }

        #expect(try app.ledgers().total == .rupees(148_000))
    }

    @Test func payingOutMoreThanIsHeldWarnsButIsAllowed() throws {
        let app = try makeApp()
        let sam = try ledger(app, "Sam")
        try entry(app, sam, "Deposit", 5_000)

        let result = try entry(app, sam, "Sent to account", -8_000)

        #expect(result.warning == "You have paid out 3,000 more than you hold for Sam.")
        #expect(try balance(app, sam) == .rupees(-3_000))
    }

    @Test func addingMoneyToAnOverdrawnLedgerDoesNotWarnAgain() throws {
        let app = try makeApp()
        let sam = try ledger(app, "Sam")
        try entry(app, sam, "Sent to account", -8_000)

        let result = try entry(app, sam, "Deposit", 2_000)

        #expect(result.warning == nil)
        #expect(try balance(app, sam) == .rupees(-6_000))
    }

    @Test func onlyLedgerPaymentsCountAgainstALedgerNotOtherMethodsWithTheSameName() throws {
        let app = try makeApp()
        let cash = try ledger(app, "Cash")
        try app.addExpense(NewExpense(
            description: "Chai", amount: .rupees(50), category: "Food & Dining", paymentMethod: .cash
        ))

        #expect(try balance(app, cash) == .zero)
    }

    @Test(arguments: [nil, Money.zero] as [Money?])
    func anEmptyEntryIsRefused(value: Money?) throws {
        let app = try makeApp()
        let sam = try ledger(app, "Sam")

        let error = #expect(throws: LedgerError.self) {
            try app.addLedgerEntry(sam.id, NewLedgerEntry(description: "Nothing", value: value))
        }

        #expect(error?.message == "Enter a value other than 0")
    }

    @Test func anExpensePaidFromALedgerLowersItAndAppearsInIt() throws {
        let app = try makeApp()
        let neighbor = try ledger(app, "Neighbor")
        try entry(app, neighbor, "Carry over", 28_000)

        try app.addExpense(NewExpense(
            description: "Repairs", amount: .rupees(4_000), category: "Home & Utilities",
            paymentMethod: .ledger("Neighbor")
        ))

        let summary = try #require(try app.ledgers().ledgers.first)
        #expect(summary.balance == .rupees(24_000))
        #expect(summary.lines.contains { $0.description == "Paid: Repairs" && $0.amount == .rupees(-4_000) })
    }

    @Test func aRefundOnALedgerPaidExpenseGoesBackToThatLedger() throws {
        let app = try makeApp()
        let neighbor = try ledger(app, "Neighbor")
        try entry(app, neighbor, "Carry over", 28_000)
        let order = try app.addExpense(NewExpense(
            description: "Order", amount: .rupees(500), category: "Shopping - Needs", paymentMethod: .ledger("Neighbor")
        ))
        try app.markRefundable(order.id!)
        #expect(try balance(app, neighbor) == .rupees(27_500))

        try app.recordReceived(order.id!, .rupees(500))

        #expect(try balance(app, neighbor) == .rupees(28_000))
    }

    @Test func borrowingLeavesLedgersAlone() throws {
        let app = try makeApp()
        let mom = try ledger(app, "Mom")
        try entry(app, mom, "Carry over", 50_000)

        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(10_000), note: "Savings"))

        #expect(try balance(app, mom) == .rupees(50_000))
    }

    @Test func deletingAnEntryTakesItOutOfTheBalance() throws {
        let app = try makeApp()
        let sam = try ledger(app, "Sam")
        try entry(app, sam, "Deposit", 100_000)
        let payout = try entry(app, sam, "Sent to account", -30_000)

        try app.deleteLedgerEntry(payout.entry.id)

        #expect(try balance(app, sam) == .rupees(100_000))
    }

    @Test func deletingAPersonsLedgerRemovesItAndItsEntries() throws {
        let app = try makeApp()
        let aunt = try ledger(app, "Aunt")
        try entry(app, aunt, "Deposit", 1_000)

        try app.deleteLedger(aunt.id)

        #expect(try app.ledgers().ledgers.isEmpty)
        #expect(try app.ledgers().total == .zero)
    }

    @Test func aLedgerWithExpensesPaidFromItCannotBeDeleted() throws {
        let app = try makeApp()
        let aunt = try ledger(app, "Aunt")
        for name in ["One", "Two", "Three"] {
            try app.addExpense(NewExpense(
                description: name, amount: .rupees(10), category: "Miscellaneous", paymentMethod: .ledger("Aunt")
            ))
        }

        let error = #expect(throws: LedgerError.self) { try app.deleteLedger(aunt.id) }

        #expect(error?.message == "Aunt has 3 expenses paid from it. Change their payment method first.")
        #expect(try app.ledgers().ledgers.count == 1)
    }

    @Test(arguments: [("", "Enter a name"), ("  ", "Enter a name"), ("mom", "A ledger called Mom already exists")])
    func aLedgerNeedsAUniqueName(name: String, message: String) throws {
        let app = try makeApp()
        try ledger(app, "Mom")

        let error = #expect(throws: LedgerError.self) { try ledger(app, name) }

        #expect(error?.message == message)
    }

    @Test func aMissingLedgerIsRefused() throws {
        let app = try makeApp()

        #expect(throws: LedgerError.self) {
            try app.addLedgerEntry(99, NewLedgerEntry(description: "Ghost", value: .rupees(1)))
        }
    }
}
