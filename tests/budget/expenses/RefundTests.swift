import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/expenses/refunds.feature (ledger refunds come with the ledgers slice)
struct RefundTests {
    private func add(
        _ app: BudgetApp, _ rupees: Int, named name: String = "Order", on date: String? = nil,
        paidWith method: PaymentMethod = .upi
    ) throws -> Expense {
        try app.addExpense(NewExpense(
            date: date.map(day), description: name, amount: .rupees(rupees), category: "Shopping - Wants",
            paymentMethod: method
        ))
    }

    private func current(_ app: BudgetApp, _ expense: Expense, month: CalendarDate.YearMonth? = nil) throws -> Expense {
        let budget = try app.monthBudget(for: month)
        return try #require(budget.expenses.first { $0.id == expense.id })
    }

    @Test func markingAnOrderRefundableMakesItPendingAtItsFullAmount() throws {
        let app = try makeApp()
        let order = try add(app, 600)

        try app.markRefundable(order.id!)

        let saved = try current(app, order)
        #expect(saved.refund == .pending)
        #expect(saved.netAmount == .rupees(600))
        let pending = try app.pendingRefunds()
        #expect(pending.expenses.count == 1)
        #expect(pending.stillToCome == .rupees(600))
    }

    @Test func anOldExpenseCanBeMarkedRefundableLater() throws {
        let app = try makeApp(today: "2026-10-30")
        let old = try add(app, 1_250, named: "Ticket", on: "2026-10-09")

        try app.markRefundable(old.id!)

        #expect(try current(app, old).refund == .pending)
    }

    @Test func aFullRefundBringsTheNetToZero() throws {
        let app = try makeApp()
        let order = try add(app, 2_000)
        try app.markRefundable(order.id!)

        try app.recordReceived(order.id!, .rupees(2_000))

        let saved = try current(app, order)
        #expect(saved.refund == .settled(received: .rupees(2_000)))
        #expect(saved.netAmount == .zero)
    }

    @Test func aPartialRefundLeavesTheDifferenceAsTheCostAndGivesBackLeftToSpend() throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Train ticket")
        try app.markRefundable(ticket.id!)
        let before = try app.monthBudget().leftToSpend

        try app.recordReceived(ticket.id!, .rupees(900))

        #expect(try current(app, ticket).netAmount == .rupees(300))
        #expect(try app.monthBudget().leftToSpend - before == .rupees(900))
    }

    @Test func aRefundThatNeverComesIsClosedWithNothingReceived() throws {
        let app = try makeApp()
        let order = try add(app, 600)
        try app.markRefundable(order.id!)

        try app.recordReceived(order.id!, .zero)

        let saved = try current(app, order)
        #expect(saved.refund == .settled(received: .zero))
        #expect(saved.netAmount == .rupees(600))
        #expect(try app.pendingRefunds().expenses.isEmpty)
    }

    @Test func theMonthSummaryCountsPendingAndSettledAndSpendsTheNet() throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Train ticket")
        let orderA = try add(app, 2_000, named: "Order A")
        let orderB = try add(app, 600, named: "Order B")
        for expense in [ticket, orderA, orderB] { try app.markRefundable(expense.id!) }
        try app.recordReceived(ticket.id!, .rupees(900))
        try app.recordReceived(orderA.id!, .rupees(2_000))

        let october = try app.monthBudget()

        #expect(october.refundsThisMonth == RefundSummary(
            pendingCount: 1, pendingStillToCome: .rupees(600), settledCount: 2, receivedTotal: .rupees(2_900)
        ))
        #expect(october.spentThisMonth == .rupees(900))
    }

    @Test func aPendingRefundFromAnEarlierMonthStaysVisibleWhenViewingAnotherMonth() throws {
        let app = try makeApp(today: "2026-10-30")
        let september = try add(app, 600, on: "2026-09-12")
        try app.markRefundable(september.id!)

        let october = try app.monthBudget()

        #expect(october.refundsThisMonth.pendingCount == 0)
        #expect(october.pendingRefundsEverywhere == PendingRefundTotal(count: 1, stillToCome: .rupees(600)))
    }

    @Test func pendingRefundsListAcrossAllMonthsOldestFirstWithATotal() throws {
        let app = try makeApp(today: "2026-10-30")
        let newer = try add(app, 300, named: "October order", on: "2026-10-20")
        let older = try add(app, 600, named: "September order", on: "2026-09-12")
        try app.markRefundable(newer.id!)
        try app.markRefundable(older.id!)

        let pending = try app.pendingRefunds()

        #expect(pending.expenses.map(\.description) == ["September order", "October order"])
        #expect(pending.stillToCome == .rupees(900))
    }

    @Test func nothingPendingShowsAnEmptyList() throws {
        let app = try makeApp()

        let pending = try app.pendingRefunds()

        #expect(pending.expenses.isEmpty)
        #expect(pending.stillToCome == .zero)
    }

    @Test func aCashExpenseCannotBeMarkedRefundable() throws {
        let app = try makeApp()
        let chai = try add(app, 500, named: "Chai", paidWith: .cash)

        let error = #expect(throws: RefundError.self) { try app.markRefundable(chai.id!) }

        #expect(error?.message == "Cash expenses can't be refunded.")
        #expect(try current(app, chai).refund == .notRefundable)
    }

    @Test func aRefundableExpenseCannotBeSwitchedToCash() throws {
        let app = try makeApp()
        let order = try add(app, 500)
        try app.markRefundable(order.id!)

        let error = #expect(throws: RefundError.self) {
            try app.updateExpense(order.id!, NewExpense(
                description: "Order", amount: .rupees(500), category: "Shopping - Wants", paymentMethod: .cash
            ))
        }

        #expect(error?.message == "Unmark it as refundable first. Cash expenses can't be refunded.")
        #expect(try current(app, order).paymentMethod == .upi)
    }

    @Test func editingAnExpenseKeepsItsRefundState() throws {
        let app = try makeApp()
        let order = try add(app, 600)
        try app.markRefundable(order.id!)
        try app.recordReceived(order.id!, .rupees(200))

        try app.updateExpense(order.id!, NewExpense(
            description: "Order renamed", amount: .rupees(600), category: "Shopping - Wants"
        ))

        #expect(try current(app, order).refund == .settled(received: .rupees(200)))
    }

    @Test func loweringTheAmountBelowWhatCameBackIsRefused() throws {
        let app = try makeApp()
        let order = try add(app, 600)
        try app.markRefundable(order.id!)
        try app.recordReceived(order.id!, .rupees(500))

        let error = #expect(throws: RefundError.self) {
            try app.updateExpense(order.id!, NewExpense(
                description: "Order", amount: .rupees(400), category: "Shopping - Wants"
            ))
        }

        #expect(error?.message == "Received can't be more than 400")
        #expect(try current(app, order).amount == .rupees(600))
    }

    @Test func theReceivedAmountCanBeCorrected() throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Ticket")
        try app.markRefundable(ticket.id!)
        try app.recordReceived(ticket.id!, .rupees(900))

        try app.recordReceived(ticket.id!, .rupees(1_000))

        #expect(try current(app, ticket).netAmount == .rupees(200))
    }

    @Test func undoingASettlementMakesItPendingAgain() throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Ticket")
        try app.markRefundable(ticket.id!)
        try app.recordReceived(ticket.id!, .rupees(900))

        try app.undoSettlement(ticket.id!)

        let saved = try current(app, ticket)
        #expect(saved.refund == .pending)
        #expect(saved.netAmount == .rupees(1_200))
    }

    @Test func unmarkingAPendingExpenseMakesItNormalAgain() throws {
        let app = try makeApp()
        let order = try add(app, 600)
        try app.markRefundable(order.id!)

        try app.unmarkRefundable(order.id!)

        let saved = try current(app, order)
        #expect(saved.refund == .notRefundable)
        #expect(saved.netAmount == .rupees(600))
    }

    @Test func aSettledExpenseMustHaveItsSettlementUndoneBeforeItCanBeUnmarked() throws {
        let app = try makeApp()
        let order = try add(app, 600)
        try app.markRefundable(order.id!)
        try app.recordReceived(order.id!, .rupees(100))

        let error = #expect(throws: RefundError.self) { try app.unmarkRefundable(order.id!) }

        #expect(error?.message == "Undo the settlement first.")
    }

    @Test(arguments: [
        (1_300, "Received can't be more than 1,200"),
        (-100, "Enter an amount of 0 or more"),
    ])
    func receivedMoneyOutsideZeroToTheAmountIsRefusedAndTheTicketStaysPending(received: Int, message: String) throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Ticket")
        try app.markRefundable(ticket.id!)

        let error = #expect(throws: RefundError.self) { try app.recordReceived(ticket.id!, .rupees(received)) }

        #expect(error?.message == message)
        #expect(try current(app, ticket).refund == .pending)
    }

    @Test func moneyCannotBeReceivedOnANormalExpense() throws {
        let app = try makeApp()
        let ticket = try add(app, 1_200, named: "Ticket")

        let error = #expect(throws: RefundError.self) { try app.recordReceived(ticket.id!, .rupees(100)) }

        #expect(error?.message == "Mark it as refundable first.")
    }

    @Test func refundingAnExpenseThatIsGoneIsRefused() throws {
        let app = try makeApp()

        #expect(throws: ExpenseNotFound.self) { try app.markRefundable(99) }
    }
}
