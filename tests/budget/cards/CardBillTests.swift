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
        #expect(CardError.invalidDueDay.message == "Enter a due day between 1 and 31.")
        #expect(CardError.nothingToPay(card: "Visa Card", month: "October 2026").message
            == "Nothing to pay for Visa Card in October 2026.")
    }

    // MARK: per-card due days, cutoff dates, carryover and unpaid count

    @Test func eachCardFollowsItsOwnMonthlyDueDayAndShowsNewSpendAfterCutoff() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        try spend(app, on: .bank("Travel Card"), 800, date: "2026-11-22")

        let nov = try line(app, travel, month: .init(year: 2026, month: 11))

        #expect(nov.cycleStart == day("2026-10-21"))
        #expect(nov.cycleEnd == day("2026-11-20"))
        #expect(nov.bill == .rupees(462))
        #expect(nov.due == .rupees(462))
        #expect(nov.newSpend == .rupees(800))
    }

    @Test func markingPaidUpToCutoffSettlesThroughThatDateAndKeepsNewerChargesForNextMonth() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        try spend(app, on: .bank("Travel Card"), 800, date: "2026-11-22")
        let nov = CalendarDate.YearMonth(year: 2026, month: 11)
        let dec = CalendarDate.YearMonth(year: 2026, month: 12)

        try app.markBillPaid(travel.id, nov, upTo: day("2026-11-20"))

        let paidNov = try line(app, travel, month: nov)
        #expect(paidNov.paid == .rupees(462))
        #expect(paidNov.paidUpTo == day("2026-11-20"))
        #expect(paidNov.due == .zero)
        #expect(paidNov.newSpend == .rupees(800))

        let decLine = try line(app, travel, month: dec)
        #expect(decLine.bill == .rupees(800))
        #expect(decLine.due == .rupees(800))
    }

    @Test func payingEarlyWithCustomCutoffMovesLaterChargesIntoNewSpendAndNextMonth() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        try spend(app, on: .bank("Travel Card"), 300, date: "2026-11-19")
        try spend(app, on: .bank("Travel Card"), 500, date: "2026-11-22")
        let nov = CalendarDate.YearMonth(year: 2026, month: 11)
        let dec = CalendarDate.YearMonth(year: 2026, month: 12)

        #expect(try app.cardPaymentAmount(travel.id, nov, upTo: day("2026-11-18")) == .rupees(462))
        try app.markBillPaid(travel.id, nov, upTo: day("2026-11-18"))

        let paidNov = try line(app, travel, month: nov)
        #expect(paidNov.paid == .rupees(462))
        #expect(paidNov.cycleEnd == day("2026-11-18"))
        #expect(paidNov.due == .zero)
        #expect(paidNov.newSpend == .rupees(800))

        let decLine = try line(app, travel, month: dec)
        #expect(decLine.cycleStart == day("2026-11-19"))
        #expect(decLine.bill == .rupees(800))
        #expect(decLine.due == .rupees(800))
    }

    @Test func anUnpaidCycleCarriesOverIntoNextMonthAndPayingLaterClearsBoth() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        try spend(app, on: .bank("Travel Card"), 800, date: "2026-11-22")
        let nov = CalendarDate.YearMonth(year: 2026, month: 11)
        let dec = CalendarDate.YearMonth(year: 2026, month: 12)

        let decBefore = try line(app, travel, month: dec)
        #expect(decBefore.carriedOver == .rupees(462))
        #expect(decBefore.bill == .rupees(800))
        #expect(decBefore.due == .rupees(1_262))

        try app.markBillPaid(travel.id, dec, upTo: day("2026-12-20"))

        #expect(try line(app, travel, month: dec).due == .zero)
        #expect(try line(app, travel, month: nov).due == .zero)
    }

    @Test func unpaidCardCountTracksCurrentCycleBillsAndIgnoresPostCutoffSpendForNextMonth() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        _ = try app.addCard(NewCard(name: "Shopping Card", dueDay: 25))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        try spend(app, on: .bank("Travel Card"), 800, date: "2026-11-22")
        try spend(app, on: .bank("Shopping Card"), 3_697, date: "2026-11-11")

        #expect(try app.cardBills().unpaidCardCount == 2)

        try app.markBillPaid(travel.id, .init(year: 2026, month: 11), upTo: day("2026-11-20"))

        #expect(try app.cardBills().unpaidCardCount == 1)
    }

    @Test func dueDayValidatesAndClampsInShortMonths() throws {
        let app = try makeApp(today: "2026-02-15")
        #expect(throws: CardError.invalidDueDay) { try app.addCard(NewCard(name: "Bad", dueDay: 0)) }
        #expect(throws: CardError.invalidDueDay) { try app.addCard(NewCard(name: "Bad", dueDay: 32)) }

        let endCard = try app.addCard(NewCard(name: "Month End", dueDay: 31))
        let feb = try line(app, endCard, month: .init(year: 2026, month: 2))
        #expect(feb.cycleEnd == day("2026-02-28"))
    }

    @Test func aCardCanBeEditedAndRenamedKeepingItsExpensesAndUnusedCardsCanBeDeleted() throws {
        let app = try makeApp(today: "2026-11-23")
        let old = try app.addCard(NewCard(name: "Old Card"))
        let unused = try app.addCard(NewCard(name: "Unused Card"))
        try spend(app, on: .bank("Old Card"), 500, date: "2026-11-10")

        let renamed = try app.updateCard(old.id, NewCard(name: "Everyday Card", dueDay: 15))

        #expect(renamed.name == "Everyday Card")
        #expect(renamed.dueDay == 15)
        #expect(try line(app, renamed, month: .init(year: 2026, month: 11)).bill == .rupees(500))

        try app.deleteCard(unused.id)
        #expect(try !app.cards().contains { $0.id == unused.id })

        #expect(throws: CardError.hasExpenses(name: "Everyday Card", count: 1)) {
            try app.deleteCard(renamed.id)
        }
    }

    @Test func cutoffDateOutsideTheCycleWindowIsRefused() throws {
        let app = try makeApp(today: "2026-11-23")
        let travel = try app.addCard(NewCard(name: "Travel Card", dueDay: 20))
        try spend(app, on: .bank("Travel Card"), 462, date: "2026-11-15")
        let nov = CalendarDate.YearMonth(year: 2026, month: 11)

        #expect(throws: CardError.cutoffOutOfRange(min: day("2026-10-21"), max: day("2026-12-19"))) {
            try app.markBillPaid(travel.id, nov, upTo: day("2026-10-01"))
        }
    }
}
