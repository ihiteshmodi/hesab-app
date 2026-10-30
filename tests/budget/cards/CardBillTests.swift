import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/cards/card-bills.feature
struct CardBillTests {
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    @discardableResult
    private func spend(
        _ app: BudgetApp, on method: PaymentMethod, _ rupees: Int, date: String = "2026-10-12", received: Int? = nil
    ) throws -> Expense {
        let expense = try app.addExpense(NewExpense(
            date: day(date), description: "Item", amount: .rupees(rupees), category: "Shopping - Needs",
            paymentMethod: method
        ))
        if let received {
            try app.markRefundable(expense.id!)
            try app.recordReceived(expense.id!, .rupees(received))
        }
        return expense
    }

    /// The October background of the feature: two cards and one UPI expense.
    private func octoberExpenses() throws -> (app: BudgetApp, visa: Card, family: Card) {
        let app = try makeApp()
        let visa = try app.addCard(NewCard(name: "Visa Card"))
        let family = try app.addCard(NewCard(name: "Family Card"))
        try spend(app, on: .bank("Visa Card"), 2_000)
        try spend(app, on: .bank("Visa Card"), 1_200, received: 900)
        try spend(app, on: .bank("Family Card"), 400)
        try spend(app, on: .bank("Family Card"), 600)
        try spend(app, on: .upi, 700)
        return (app, visa, family)
    }

    private func line(_ app: BudgetApp, _ card: Card, month: CalendarDate.YearMonth? = nil) throws -> CardBillLine {
        try #require(try app.cardBills(for: month ?? october).lines.first { $0.card == card })
    }

    @Test func eachCardShowsWhatItWillCostAndUpiHasNoBill() throws {
        let (app, visa, family) = try octoberExpenses()

        let bills = try app.cardBills(for: october)

        #expect(try line(app, visa).bill == .rupees(2_300))
        #expect(try line(app, family).bill == .rupees(1_000))
        #expect(bills.totalDue == .rupees(3_300))
        #expect(!bills.lines.contains { $0.card.name == "UPI" })
    }

    @Test func tickingABillAsPaidSettlesItWithoutTouchingLeftToSpend() throws {
        let (app, visa, _) = try octoberExpenses()
        let leftBefore = try app.monthBudget().leftToSpend

        try app.markBillPaid(visa.id, october)

        let paid = try line(app, visa)
        #expect(paid.paid == .rupees(2_300))
        #expect(paid.due == .zero)
        #expect(paid.isPaid)
        #expect(try app.cardBills(for: october).totalDue == .rupees(1_000))
        #expect(try app.monthBudget().leftToSpend == leftBefore)
    }

    @Test func aChargeAddedAfterPayingShowsAsStillDue() throws {
        let (app, visa, _) = try octoberExpenses()
        try app.markBillPaid(visa.id, october)

        try spend(app, on: .bank("Visa Card"), 150)

        #expect(try line(app, visa).due == .rupees(150))
    }

    @Test func tickingAgainPaysTheChargesAddedSince() throws {
        let (app, visa, _) = try octoberExpenses()
        try app.markBillPaid(visa.id, october)
        try spend(app, on: .bank("Visa Card"), 150)

        try app.markBillPaid(visa.id, october)

        #expect(try line(app, visa).due == .zero)
        #expect(try line(app, visa).paid == .rupees(2_450))
    }

    @Test func unTickingABillBringsItsFullAmountBack() throws {
        let (app, visa, _) = try octoberExpenses()
        try app.markBillPaid(visa.id, october)

        try app.unmarkBillPaid(visa.id, october)

        #expect(try line(app, visa).due == .rupees(2_300))
        #expect(try line(app, visa).paid == .zero)
        #expect(try !line(app, visa).isPaid)
    }

    @Test func aLargerRefundLowersTheBill() throws {
        let (app, visa, _) = try octoberExpenses()
        let ticket = try #require(try app.monthBudget().expenses.first { $0.netAmount == .rupees(300) })

        try app.recordReceived(ticket.id!, .rupees(1_200))

        #expect(try line(app, visa).bill == .rupees(2_000))
    }

    @Test func aRefundAfterPayingNeverLeavesANegativeDue() throws {
        let (app, visa, _) = try octoberExpenses()
        try app.markBillPaid(visa.id, october)
        let ticket = try #require(try app.monthBudget().expenses.first { $0.netAmount == .rupees(300) })

        try app.recordReceived(ticket.id!, .rupees(1_200))

        #expect(try line(app, visa).due == .zero)
    }

    @Test func aMonthWithNoCardSpendingSaysSo() throws {
        let (app, _, _) = try octoberExpenses()

        let september = try app.cardBills(for: .init(year: 2026, month: 9))

        #expect(!september.hasCardSpending)
        #expect(september.totalDue == .zero)
    }

    @Test func spendingInAnotherMonthStaysOutOfThisBill() throws {
        let (app, visa, _) = try octoberExpenses()
        try spend(app, on: .bank("Visa Card"), 5_000, date: "2026-09-30")

        #expect(try line(app, visa).bill == .rupees(2_300))
        #expect(try line(app, visa, month: .init(year: 2026, month: 9)).bill == .rupees(5_000))
    }

    @Test func payingOneMonthDoesNotPayAnother() throws {
        let (app, visa, _) = try octoberExpenses()
        try spend(app, on: .bank("Visa Card"), 5_000, date: "2026-09-30")

        try app.markBillPaid(visa.id, .init(year: 2026, month: 9))

        #expect(try line(app, visa).due == .rupees(2_300))
    }

    @Test func aNewCardAppearsInCardBillsBeforeAnyOneSpendsOnIt() throws {
        let app = try makeApp()

        let rewards = try app.addCard(NewCard(name: "Rewards Card"))

        #expect(try app.cards().contains(rewards))
        #expect(try line(app, rewards).bill == .zero)
    }

    @Test func aFreshInstallOffersACreditCard() throws {
        let app = try makeApp()

        #expect(try app.cards().map(\.name) == ["Credit Card"])
    }

    @Test func aCardNeedsANameThatIsNotAlreadyTaken() throws {
        let app = try makeApp()
        try app.addCard(NewCard(name: "Visa Card"))

        #expect(throws: CardError.nameMissing) { try app.addCard(NewCard(name: "  ")) }
        #expect(throws: CardError.nameTaken("Visa Card")) { try app.addCard(NewCard(name: "visa card")) }
    }

    @Test func aBillWithNothingOnItCannotBeTickedAsPaid() throws {
        let app = try makeApp()
        let rewards = try app.addCard(NewCard(name: "Rewards Card"))

        #expect(throws: CardError.nothingToPay(card: "Rewards Card", month: "October 2026")) {
            try app.markBillPaid(rewards.id, october)
        }
    }

    @Test func errorsReadInPlainWords() {
        #expect(CardError.nameMissing.message == "Enter a name")
        #expect(CardError.nameTaken("Visa Card").message == "A card called Visa Card already exists")
        #expect(CardError.nothingToPay(card: "Visa Card", month: "October 2026").message
            == "Nothing to pay for Visa Card in October 2026.")
    }
}
