import Foundation
import Testing
@testable import HisaabCore

/// The main ledger follows bank and card money only; cash stays inside the trip or in Cash in Hand.
struct TripLedgerTests {
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    private func ledger(_ b: Bali) throws -> Money? { try ledgerEntry(b.app, named: "Bali trip expenses") }

    // MARK: what I pay by card

    @Test func whatIPayByCardGoesToTheLedgerAtOnceAtTheCardCharge() throws {
        let b = try bali()

        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        #expect(try ledger(b) == .rupees(2_150))
    }

    @Test func withoutACardChargeTheTripRateIsUsed() throws {
        let b = try bali()

        try b.iPaid("Dinner", idr: 400_000)

        #expect(try ledger(b) == .rupees(2_120))
    }

    @Test func whatSomeoneElsePaidIsNotMineUntilIPayThemBack() throws {
        let b = try bali()
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", amount: .rupees(300_000), paidBy: .person(b.ana.id), split: .equal(b.everyone)
        ))

        #expect(try ledger(b) == nil)
        #expect(try b.owes(b.ana) == .rupees(-75_000))
    }

    @Test func eachExpenseKeepsItsOwnCardCharge() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_200)

        try b.iPaid("Taxi", idr: 100_000, card: 520)

        #expect(try ledger(b) == .rupees(2_720))
        #expect(try b.summary().myShareHome == .rupees(680))
    }

    @Test func theLedgerEntryHasTheChosenNameAndOneEntryOnly() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        try b.app.updateTrip(b.trip.id, NewTrip(
            name: "Bali trip", currency: "IDR", rate: Decimal(string: "0.0053")!, ledgerName: "Bali holiday",
            category: "Lifestyle", subCategory: "Vacation"
        ))

        #expect(try ledgerEntry(b.app, named: "Bali holiday") == .rupees(2_150))
        #expect(try ledger(b) == nil)
        #expect(try b.app.monthBudget(for: october).expenses.count == 1)
    }

    @Test func aBlankLedgerNameFallsBackToTheTripName() throws {
        let b = try bali()

        #expect(b.trip.ledgerName == "Bali trip expenses")
    }

    @Test func theEntryTakesTheTripsCategoryAndPaymentMethod() throws {
        let b = try bali()

        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        let entry = try #require(try b.app.monthBudget(for: october).expenses.first)
        #expect(entry.category == "Lifestyle")
        #expect(entry.subCategory == "Vacation")
    }

    @Test func theEntryIsDatedOnTheEndDateElseTheLastActivity() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150, date: "2026-10-12")
        try b.iPaid("Taxi", idr: 100_000, card: 520, date: "2026-10-14")

        #expect(try b.app.monthBudget(for: october).expenses.first?.date == day("2026-10-14"))
    }

    // MARK: money back by bank

    @Test func moneyPaidBackByBankLowersTheEntry() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        try b.iPaid("Temple tickets", idr: 740_000, card: 3_925)

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(530), method: .bank)

        #expect(try ledger(b) == .rupees(5_545))
    }

    @Test func payingAFriendByBankRaisesTheEntry() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .iPaidThem, .rupees(530), method: .bank)

        #expect(try ledger(b) == .rupees(2_680))
    }

    @Test func undoingAPaymentPutsTheEntryBack() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        let payment = try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(530))

        try b.app.deleteTripSettlement(payment.id)

        #expect(try ledger(b) == .rupees(2_150))
    }

    @Test func theEntryDisappearsWhenNothingNetLeftMyBank() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(2_150))

        #expect(try ledger(b) == nil)
        #expect(try b.app.monthBudget(for: october).expenses.isEmpty)
    }

    @Test func deletingAnExpenseOrTheTripUpdatesTheEntry() throws {
        let b = try bali()
        let dinner = try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        try b.iPaid("Taxi", idr: 100_000, card: 520)

        try b.app.deleteTripExpense(dinner.id)
        #expect(try ledger(b) == .rupees(520))

        try b.app.deleteTrip(b.trip.id)
        #expect(try b.app.monthBudget(for: october).expenses.isEmpty)
    }

    // MARK: cash never touches the ledger

    @Test func cashFromAFriendGoesToTripCashNotTheLedger() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(150_000), method: .cashTrip)

        #expect(try ledger(b) == .rupees(2_150))
        #expect(try b.summary().cash.balance == .rupees(150_000))
        #expect(try b.owes(b.raj) == .rupees(-50_000))
    }

    @Test func cashPaidToAFriendTakesFromTripCashNotTheLedger() throws {
        let b = try bali()
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", amount: .rupees(300_000), paidBy: .person(b.ana.id), split: .equal(b.everyone)
        ))
        try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(150_000), method: .cashTrip)

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .iPaidThem, .rupees(75_000), method: .cashTrip)

        #expect(try ledger(b) == nil)
        #expect(try b.summary().cash.balance == .rupees(75_000))
        #expect(try b.owes(b.ana) == .zero)
    }

    @Test func rupeeNotesMoveTheMainCashInHand() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        try b.app.recordTripSettlement(b.trip.id, personID: b.mira.id, .theyPaidMe, .rupees(265), method: .cashHome)

        #expect(try ledger(b) == .rupees(2_150))
        let cash = try b.app.cashInHand()
        #expect(cash.balance == .rupees(265))
        #expect(cash.lines.last?.description == "Bali trip: Mira paid me in cash")
        #expect(try b.summary().cash.balance == .zero)
        #expect(try b.summary().receivedCashHome == .rupees(265))
    }

    @Test func rupeeNotesIPayComeOutOfMainCashInHand() throws {
        let b = try bali()
        try b.app.setCashInHand(to: .rupees(1_000))
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", amount: .rupees(300_000), paidBy: .person(b.ana.id), split: .equal(b.everyone)
        ))

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .iPaidThem, .rupees(300), method: .cashHome)

        #expect(try b.app.cashInHand().balance == .rupees(700))
    }

    @Test func anExpenseIPayInCashTakesFromTripCashAndSkipsTheLedger() throws {
        let b = try bali()
        try b.app.setTripCash(b.trip.id, to: .rupees(200_000))

        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Warung lunch", amount: .rupees(120_000), paidWith: .cash, split: .equal(b.everyone), paidInHome: .rupees(999)
        ))

        #expect(try ledger(b) == nil)
        #expect(try b.summary().cash.balance == .rupees(80_000))
        #expect(try b.summary().expenses.first?.paidInHome == nil)
        #expect(try b.owes(b.ana) == .rupees(30_000))
    }

    @Test func aCashExpenseInAHomeCurrencyTripTakesFromMainCashInHand() throws {
        let g = try goa()
        try g.app.setCashInHand(to: .rupees(2_000))

        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Beach shack", amount: .rupees(600), paidWith: .cash, split: .equal([.me, .person(g.ana.id)])
        ))

        #expect(try ledgerEntry(g.app, named: "Goa weekend expenses") == nil)
        #expect(try g.app.cashInHand().balance == .rupees(1_400))
    }

    @Test func aCashExpenseSomeoneElsePaidIsNotMyCash() throws {
        let b = try bali()
        try b.app.setTripCash(b.trip.id, to: .rupees(100_000))

        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", amount: .rupees(300_000), paidBy: .person(b.ana.id), paidWith: .cash, split: .equal(b.everyone)
        ))

        #expect(try b.summary().cash.balance == .rupees(100_000))
        #expect(try b.summary().expenses.first?.paidWith == .bank)
    }

    // MARK: inside the trip, cash counts too

    @Test func netCostCountsCashSpentAndCashReceivedAtTheTripRate() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Warung lunch", amount: .rupees(120_000), paidWith: .cash, split: .equal(b.everyone)
        ))
        try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(150_000), method: .cashTrip)

        let summary = try b.summary()

        #expect(summary.ledgerAmount == .rupees(2_150))
        #expect(summary.netCost == .rupees(2_150 + 636 - 795))
    }

    @Test func onceEveryoneIsSquareNetCostIsMyShare() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Villa", amount: .rupees(5_622), split: .equal([.me, .person(g.ana.id)])
        ))
        try g.app.recordTripSettlement(g.trip.id, personID: g.ana.id, .theyPaidMe, .rupees(2_811), method: .bank)

        let summary = try g.app.tripSummary(g.trip.id)

        #expect(summary.netCost == .rupees(2_811))
        #expect(summary.ledgerAmount == .rupees(2_811))
    }
}
